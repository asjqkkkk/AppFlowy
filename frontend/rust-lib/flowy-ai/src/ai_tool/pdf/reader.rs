use flowy_error::{FlowyError, FlowyResult};
use futures::{Stream, StreamExt};
use lopdf::{Document, Object};
use ollama_rs::Ollama;
use std::path::{Path, PathBuf};
use std::pin::Pin;

use crate::ai_tool::pdf::image::extract_images_single_page;
use crate::ai_tool::pdf::text::join_text_fragments;
use crate::ai_tool::pdf::{
  image::extract_images,
  text::extract_text,
  types::{PdfConfig, PdfContent},
};
use crate::local_ai::chat::retriever::EmbedFileProgress;

/// PDF reader that extracts text and images from PDF files
pub struct PdfReader {
  path: PathBuf,
  ollama: Ollama,
  config: PdfConfig,
}

impl PdfReader {
  pub fn with_config(path: impl AsRef<Path>, config: PdfConfig) -> Self {
    Self {
      path: path.as_ref().to_path_buf(),
      ollama: Ollama::default(),
      config,
    }
  }

  /// Sets a custom Ollama instance
  pub fn with_ollama(mut self, ollama: Ollama) -> Self {
    self.ollama = ollama;
    self
  }

  /// Reads all content from the PDF
  pub async fn read_all(&self) -> FlowyResult<PdfContent> {
    let doc = load_pdf(&self.path)?;

    if doc.is_encrypted() {
      return Err(FlowyError::invalid_data().with_context("PDF is encrypted"));
    }

    self.extract_content(&doc).await
  }

  /// Reads all content from the PDF as a stream with progress updates
  pub fn read_all_stream(
    &self,
  ) -> Pin<Box<dyn Stream<Item = FlowyResult<EmbedFileProgress>> + Send>> {
    let path = self.path.clone();
    let ollama = self.ollama.clone();
    let config = self.config.clone();

    let stream = async_stream::stream! {
      // Load the PDF document
      let doc = match load_pdf(&path) {
        Ok(doc) => doc,
        Err(e) => {
          yield Err(e);
          return;
        }
      };

      if doc.is_encrypted() {
        yield Err(FlowyError::invalid_data().with_context("PDF is encrypted"));
        return;
      }

      // Get total page count
      let pages = doc.get_pages();
      let total_pages = pages.len();

      // Initialize content accumulator
      let mut content = PdfContent::new();

      // Process pages one by one
      for (idx, (&page_num, _)) in pages.iter().enumerate() {
        let current_page = idx + 1;

        // Emit progress update
        yield Ok(EmbedFileProgress::ReadingFile {
          progress: idx as f32 / total_pages as f32,
          current_page: Some(current_page),
          total_pages: Some(total_pages),
        });

        // Extract text from current page if enabled
        if config.extract_text {
          yield Ok(EmbedFileProgress::ReadingFileDetails{
            details: format!("Extracting text from page {}", page_num),
          });
          if let Err(e) = extract_text_single_page(&doc, page_num, &mut content) {
            content.add_error(page_num, format!("Failed to extract text: {}", e));
          }
        }

        // Extract images from current page if enabled
        if config.extract_images {
          let mut image_stream = extract_images_single_page(&doc, page_num, &ollama, &config);
          while let Some(progress_result) = image_stream.next().await {
            match progress_result {
              Ok(progress) => {
                // Forward all progress updates except Completed
                match progress {
                  EmbedFileProgress::Completed { content: image_content } => {
                    yield Ok(EmbedFileProgress::Completed {
                      content: image_content.clone(),
                    });

                    if !image_content.is_empty() {
                      content.add_text(page_num, image_content);
                    }
                  },
                  EmbedFileProgress::Error { message } => {
                    content.add_error(page_num, message.clone());
                    yield Ok(EmbedFileProgress::Error { message });
                  },
                  other => {
                    yield Ok(other);
                  }
                }
              },
              Err(e) => {
                // Handle stream errors
                content.add_error(page_num, format!("Failed to extract images: {}", e));
                yield Ok(EmbedFileProgress::Error {
                  message: format!("Failed to extract images from page {}: {}", page_num, e),
                });
              }
            }
          }
        }
      }

      // Emit final progress
      yield Ok(EmbedFileProgress::ReadingFile {
        progress: 1.0,
        current_page: Some(total_pages),
        total_pages: Some(total_pages),
      });

      // Return the completed content
      yield Ok(EmbedFileProgress::Completed {
        content: content.into_text()
      });
    };

    Box::pin(stream)
  }

  /// Extracts content from the loaded document
  async fn extract_content(&self, doc: &Document) -> FlowyResult<PdfContent> {
    let mut content = PdfContent::new();

    // Extract text if enabled
    if self.config.extract_text {
      extract_text(doc, &mut content)?;
    }

    // Extract images if enabled
    if self.config.extract_images {
      extract_images(doc, &mut content, &self.ollama, &self.config).await?;
    }

    Ok(content)
  }
}

/// Loads a PDF document with filtering
fn load_pdf<P: AsRef<Path>>(path: P) -> FlowyResult<Document> {
  Document::load_filtered(path, filter_func).map_err(|e| FlowyError::internal().with_context(e))
}

/// Filter function to optimize PDF loading
fn filter_func(id: (u32, u16), obj: &mut Object) -> Option<((u32, u16), Object)> {
  // Filter out unnecessary metadata
  if let Ok(name) = obj.type_name() {
    // Keep XObject so that images survive
    const IGNORE: &[&[u8]] = &[b"Length", b"PTEX.FileName", b"FontDescriptor"];
    if IGNORE.contains(&name) {
      return None;
    }
  }

  // Remove unnecessary dictionary entries
  if let Ok(dict) = obj.as_dict_mut() {
    let keys_to_remove = [
      b"Producer".as_ref(),
      b"ModDate".as_ref(),
      b"Creator".as_ref(),
      b"ProcSet".as_ref(),
    ];

    for key in &keys_to_remove {
      dict.remove(key);
    }

    if dict.is_empty() {
      return None;
    }
  }

  Some((id, obj.to_owned()))
}

// Helper function to extract text from a single page
fn extract_text_single_page(
  doc: &Document,
  page: u32,
  content: &mut PdfContent,
) -> FlowyResult<()> {
  match doc.extract_text(&[page]) {
    Ok(text) => {
      let raw_lines: Vec<String> = text
        .lines()
        .map(|line| line.trim().to_owned())
        .filter(|line| !line.is_empty())
        .collect();

      let joined_lines = join_text_fragments(raw_lines);
      for line in joined_lines {
        content.add_text(page, line);
      }
      Ok(())
    },
    Err(e) => Err(FlowyError::invalid_data().with_context(e)),
  }
}
