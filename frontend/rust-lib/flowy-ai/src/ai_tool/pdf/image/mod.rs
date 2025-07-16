pub mod formats;

use flowy_error::{FlowyError, FlowyResult};
use futures::Stream;
use futures::future::join_all;
use futures::stream::StreamExt;
use lopdf::{Document, Object};
use ollama_rs::Ollama;
use std::pin::Pin;
use std::sync::Arc;
use tokio::sync::Semaphore;
use tokio::sync::mpsc;
use tracing::debug;

use self::formats::ImageFormatRegistry;
use crate::ai_tool::pdf::llm::{ImageAnalysisConfig, extract_text_from_image};
use crate::ai_tool::pdf::types::{PdfConfig, PdfContent};
use crate::local_ai::chat::retriever::EmbedFileProgress;
use crate::local_ai::util::is_model_support_vision;

/// Extracts and processes images from a single page of a PDF document
pub fn extract_images_single_page(
  doc: &Document,
  page: u32,
  ollama: &Ollama,
  config: &PdfConfig,
) -> Pin<Box<dyn Stream<Item = FlowyResult<EmbedFileProgress>> + Send>> {
  let doc = doc.clone();
  let ollama = ollama.clone();
  let config = config.clone();

  let stream = async_stream::stream! {
    let format_registry = Arc::new(ImageFormatRegistry::new());
    let analysis_config = Arc::new(ImageAnalysisConfig::new(config.image_model.clone()));
    let image_semaphore = Arc::new(Semaphore::new(config.max_concurrent_images));
    let vision_enabled = match ollama.show_model_info(config.image_model.to_string()).await {
      Ok(model_info) => is_model_support_vision(&model_info),
      Err(_) => {
        false
      }
    };

       // Get the page ID for this page number
    let pages = doc.get_pages();
    let pid = match pages.get(&page) {
      Some(pid) => *pid,
      None => {
        yield Err(FlowyError::invalid_data().with_context(format!("Page {} not found", page)));
        return;
      }
    };

    // Emit start processing for this page
    yield Ok(EmbedFileProgress::Other {
      details: format!("Extracting images from page {}", page),
    });

    // Get page dictionary
    let page_dict = match doc.get_dictionary(pid) {
      Ok(dict) => dict,
      Err(e) => {
        yield Err(FlowyError::internal().with_context(e));
        return;
      }
    };

    let resources = match page_dict.get_deref(b"Resources", &doc).and_then(|o| o.as_dict()) {
      Ok(res) => res,
      Err(e) => {
        yield Err(FlowyError::internal().with_context(e));
        return;
      }
    };

    let xobjects = match resources.get_deref(b"XObject", &doc) {
      Ok(obj) => match obj.as_dict() {
        Ok(dict) => dict,
        Err(e) => {
          yield Err(FlowyError::internal().with_context(e));
          return;
        }
      },
      Err(_) => {
        debug!("No XObjects found on page {}", page);
        yield Ok(EmbedFileProgress::Completed {
          content: String::new(),
        });
        return;
      },
    };

    let (tx, mut rx) = mpsc::unbounded_channel();
    let mut image_tasks = Vec::new();
    let mut image_count = 0;

    for (name, xobj) in xobjects.iter() {
      if let Object::Reference(oid) = xobj {
        if let Ok(Object::Stream(stream)) = doc.get_object(*oid) {
          if is_image_stream(stream) {
            if !vision_enabled {
              yield Ok(EmbedFileProgress::ModelNotSupported {
                message: format!("{} doesn't support vision, skip process image", config.image_model),
              });
              return;
            }

            image_count += 1;
            debug!(
              "Found image #{} on page {} (XObject: {:?})",
              image_count,
              page,
              String::from_utf8_lossy(name)
            );

            let stream_clone = stream.clone();
            let page_num = page;
            let ollama_clone = ollama.clone();
            let format_registry_clone = format_registry.clone();
            let analysis_config_clone = analysis_config.clone();
            let semaphore_clone = image_semaphore.clone();
            let image_idx = image_count;
            let tx_clone = tx.clone();

            let task = tokio::spawn(async move {
              // Acquire image processing permit
              let _permit = match semaphore_clone.acquire().await {
                Ok(permit) => permit,
                Err(e) => {
                  debug!("Failed to acquire semaphore permit for image {}: {}", image_idx, e);
                  let _ = tx_clone.send((image_idx, Err(FlowyError::internal().with_context(
                    format!("Failed to acquire semaphore: {}", e)
                  ))));
                  return;
                }
              };

              // Create the stream from process_single_image
              let mut stream = process_single_image(
                stream_clone,
                page_num,
                ollama_clone,
                format_registry_clone,
                analysis_config_clone,
                vision_enabled,
              );

              // Forward events immediately through the channel
              while let Some(event) = stream.next().await {
                if tx_clone.send((image_idx, event)).is_err() {
                  break;
                }
              }
            });

            image_tasks.push(task);
          }
        }
      }
    }

    if image_count == 0 {
      debug!("No images found on page {}", page);
      yield Ok(EmbedFileProgress::Completed {
        content: String::new(),
      });
      return;
    }

    debug!("Page {}: Found {} images, processing them", page, image_count);
    drop(tx);

    // Process images concurrently and yield events immediately
    let mut all_content = Vec::new();
    let mut errors = Vec::new();
    let mut processed_images = std::collections::HashSet::new();

    // Receive and yield events as they arrive
    while let Some((image_idx, event)) = rx.recv().await {
      match &event {
        Ok(EmbedFileProgress::Completed { content }) => {
          all_content.push(format!("[Page {} Image {}]: {}", page, image_idx, content));
          processed_images.insert(image_idx);

          // Yield completion event
          yield event;

          // Yield progress update
          yield Ok(EmbedFileProgress::Other {
            details: format!("Completed image {} of {} from page {}", processed_images.len(), image_count, page),
          });

          let progress = processed_images.len() as f32 / image_count as f32;
          yield Ok(EmbedFileProgress::ReadingFile {
            progress,
            current_page: Some(page as usize),
            total_pages: None,
          });
        },
        Ok(EmbedFileProgress::Error { message }) => {
          errors.push(message.clone());
          processed_images.insert(image_idx);
          yield event;
        },
        _ => {
          // Forward other progress events immediately
          yield event;
        },
      }
    }

    // Wait for all tasks to complete
    for task in image_tasks {
      let _ = task.await;
    }

    debug!(
      "Page {}: Processed {} images successfully",
      page, all_content.len()
    );

    // Return completed content
    if !all_content.is_empty() {
      yield Ok(EmbedFileProgress::Completed {
        content: all_content.join("\n\n"),
      });
    } else {
      yield Ok(EmbedFileProgress::Completed {
        content: String::new(),
      });
    }
  };

  Box::pin(stream)
}

/// Extracts and processes images from a PDF document
pub async fn extract_images(
  doc: &Document,
  content: &mut PdfContent,
  ollama: &Ollama,
  config: &PdfConfig,
) -> FlowyResult<()> {
  let format_registry = Arc::new(ImageFormatRegistry::new());
  let analysis_config = Arc::new(ImageAnalysisConfig::new(config.image_model.clone()));

  // Check vision support once at the beginning
  let vision_enabled = match ollama.show_model_info(config.image_model.to_string()).await {
    Ok(model_info) => is_model_support_vision(&model_info),
    Err(_) => false,
  };

  // Create semaphore for image concurrency control
  let image_semaphore = Arc::new(Semaphore::new(config.max_concurrent_images));

  // Get all pages
  let pages: Vec<_> = doc.get_pages().into_iter().collect();
  let total_pages = pages.len();

  debug!(
    "Starting image extraction from PDF with {} pages (batch size: {})",
    total_pages, config.max_concurrent_pages
  );

  // Process pages in batches
  for (batch_idx, batch) in pages.chunks(config.max_concurrent_pages).enumerate() {
    let batch_start = batch_idx * config.max_concurrent_pages + 1;
    let batch_end = batch_start + batch.len() - 1;

    debug!(
      "Processing batch {}/{} (pages {}-{}/{})",
      batch_idx + 1,
      total_pages.div_ceil(config.max_concurrent_pages),
      batch_start,
      batch_end,
      total_pages
    );

    // Create tasks for this batch
    let mut batch_tasks = Vec::new();

    for (idx_in_batch, (page, pid)) in batch.iter().enumerate() {
      let current_page = batch_start + idx_in_batch;
      debug!("Processing page {}/{}", current_page, total_pages);

      let doc_clone = doc.clone();
      let page = *page;
      let pid = *pid;
      let ollama_clone = ollama.clone();
      let format_registry_clone = format_registry.clone();
      let analysis_config_clone = analysis_config.clone();
      let image_semaphore_clone = image_semaphore.clone();

      let task = tokio::spawn(async move {
        let result = process_page_images(
          &doc_clone,
          page,
          pid,
          &ollama_clone,
          &format_registry_clone,
          &analysis_config_clone,
          &image_semaphore_clone,
          vision_enabled,
        )
        .await;

        (page, result)
      });

      batch_tasks.push(task);
    }

    // Wait for this batch to complete
    let batch_results = join_all(batch_tasks).await;

    // Process results from this batch
    for result in batch_results {
      match result {
        Ok((page, Ok(page_content))) => {
          // Add text content
          for text in page_content.text {
            content.add_text(page, text);
          }
          // Add errors
          for error in page_content.errors {
            content.add_error(page, error);
          }
        },
        Ok((page, Err(e))) => {
          debug!("Failed to process images on page {}: {}", page, e);
          content.add_error(page, format!("Failed to process images: {}", e));
        },
        Err(e) => {
          debug!("Task failed: {}", e);
        },
      }
    }

    debug!("Completed batch {} of page processing", batch_idx + 1);
  }

  debug!("Completed image extraction from all {} pages", total_pages);
  Ok(())
}

/// Result from processing a single page
struct PageProcessResult {
  text: Vec<String>,
  errors: Vec<String>,
}

#[allow(clippy::too_many_arguments)]
async fn process_page_images(
  doc: &Document,
  page: u32,
  pid: (u32, u16),
  ollama: &Ollama,
  format_registry: &Arc<ImageFormatRegistry>,
  analysis_config: &Arc<ImageAnalysisConfig>,
  image_semaphore: &Arc<Semaphore>,
  vision_enabled: bool,
) -> FlowyResult<PageProcessResult> {
  let mut result = PageProcessResult {
    text: Vec::new(),
    errors: Vec::new(),
  };

  let page_dict = doc
    .get_dictionary(pid)
    .map_err(|e| FlowyError::internal().with_context(e))?;

  let resources = page_dict
    .get_deref(b"Resources", doc)
    .and_then(|o| o.as_dict())
    .map_err(|e| FlowyError::internal().with_context(e))?;

  let xobjects = match resources.get_deref(b"XObject", doc) {
    Ok(obj) => obj
      .as_dict()
      .map_err(|e| FlowyError::internal().with_context(e))?,
    Err(_) => {
      debug!("No XObjects found on page {}", page);
      return Ok(result);
    },
  };

  // Collect all image streams first
  let mut image_tasks = Vec::new();
  let mut image_count = 0;

  for (name, xobj) in xobjects.iter() {
    if let Object::Reference(oid) = xobj {
      if let Ok(Object::Stream(stream)) = doc.get_object(*oid) {
        if is_image_stream(stream) {
          image_count += 1;
          debug!(
            "Found image #{} on page {} (XObject: {:?})",
            image_count,
            page,
            String::from_utf8_lossy(name)
          );

          // Create a task for each image
          let stream_clone = stream.clone();
          let page_num = page;
          let ollama_clone = ollama.clone();
          let format_registry_clone = format_registry.clone();
          let analysis_config_clone = analysis_config.clone();
          let semaphore_clone = image_semaphore.clone();

          let task = tokio::spawn(async move {
            let _permit = match semaphore_clone.acquire().await {
              Ok(permit) => permit,
              Err(e) => {
                debug!(
                  "Failed to acquire semaphore permit for image processing: {}",
                  e
                );
                return None;
              },
            };

            // Create the stream from process_single_image
            let mut stream = process_single_image(
              stream_clone,
              page_num,
              ollama_clone,
              format_registry_clone,
              analysis_config_clone,
              vision_enabled,
            );

            // Collect all events from the stream to get the final content
            let mut final_content = None;

            while let Some(event) = stream.next().await {
              match event {
                Ok(EmbedFileProgress::Completed { content }) => {
                  final_content = Some((page_num, content));
                },
                _ => {
                  // Other events are not needed here
                },
              }
            }

            final_content
          });

          image_tasks.push(task);
        }
      }
    }
  }

  debug!(
    "Page {}: Found {} images, processing them in parallel",
    page, image_count
  );

  // Wait for all image processing tasks to complete
  let results = join_all(image_tasks).await;

  // Process results
  let mut processed_count = 0;
  for task_result in results {
    match task_result {
      Ok(Some((_page_num, text))) => {
        result.text.push(text);
        processed_count += 1;
      },
      Ok(None) => {
        // Image processing failed internally, error already logged
      },
      Err(e) => {
        debug!("Task failed for image on page {}: {}", page, e);
        result
          .errors
          .push(format!("Failed to process image: {}", e));
      },
    }
  }

  debug!(
    "Page {}: Found {} images, processed {} successfully",
    page, image_count, processed_count
  );
  Ok(result)
}

/// Checks if a stream represents an image
fn is_image_stream(stream: &lopdf::Stream) -> bool {
  stream
    .dict
    .get(b"Subtype")
    .ok()
    .and_then(|n| n.as_name().ok())
    .map(|subtype_bytes| subtype_bytes == b"Image")
    .unwrap_or(false)
}

/// Processes a single image stream
fn process_single_image(
  stream: lopdf::Stream,
  page: u32,
  ollama: Ollama,
  format_registry: Arc<ImageFormatRegistry>,
  analysis_config: Arc<ImageAnalysisConfig>,
  vision_enabled: bool,
) -> Pin<Box<dyn Stream<Item = FlowyResult<EmbedFileProgress>> + Send>> {
  let stream_clone = stream.clone();
  let stream = async_stream::stream! {
  if vision_enabled {
      // Yield progress for image extraction
      yield Ok(EmbedFileProgress::Other {
        details: format!("Extracting image data from page {}", page),
      });

      let result =
        tokio::task::spawn_blocking(move || format_registry.process_image(&stream_clone)).await;
      match result {
        Ok(Ok(jpeg_bytes)) => {
          debug!(
            "Successfully extracted image on page {} (size: {} bytes)",
            page,
            jpeg_bytes.len()
          );

          // Yield progress for AI analysis
          yield Ok(EmbedFileProgress::Other {
            details: format!("Analyzing image on page {} with AI model", page),
          });

          // Analyze the image with AI
          match extract_text_from_image(&ollama, jpeg_bytes, &analysis_config).await {
            Ok(description) => {
              // Yield completed with the description
              yield Ok(EmbedFileProgress::Completed {
                content: description,
              });
            },
            Err(e) => {
              debug!("Failed to analyze image on page {}: {}", page, e);
              yield Ok(EmbedFileProgress::Error {
                message: format!("Failed to analyze image on page {}: {}", page, e),
              });
            },
          }
        },
        Ok(Err(e)) => {
          yield Ok(EmbedFileProgress::Error {
            message: format!("Failed to extract image on page {}: {}", page, e),
          });
        },
        Err(e) => {
          yield Ok(EmbedFileProgress::Error {
            message: format!("Failed to process image on page {}: {}", page, e),
          });
        },
      }
    }
  };

  Box::pin(stream)
}

#[cfg(test)]
mod tests {

  #[test]
  fn test_is_image_stream() {
    // This would require creating mock Stream objects
    // Left as an exercise for actual implementation
  }
}
