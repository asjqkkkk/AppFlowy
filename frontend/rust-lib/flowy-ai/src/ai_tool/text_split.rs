use crate::embeddings::indexer::LocalEmbeddingModel;
use flowy_ai_pub::entities::{EmbeddedChunk, SOURCE, SOURCE_ID, SOURCE_NAME};
use flowy_error::FlowyError;
use serde_json::json;
use text_splitter::{ChunkConfig, TextSplitter};
use tracing::{debug, trace, warn};
use twox_hash::xxhash64::Hasher;

pub enum RAGSource {
  AppFlowyDocument,
  LocalFile { file_name: String },
}

impl RAGSource {
  pub fn file_name(&self) -> &str {
    match self {
      RAGSource::AppFlowyDocument => "document",
      RAGSource::LocalFile { file_name } => file_name.as_str(),
    }
  }
  pub fn as_str(&self) -> &str {
    match self {
      RAGSource::AppFlowyDocument => "appflowy",
      RAGSource::LocalFile { .. } => "local_file",
    }
  }
}

/// chunk_size:
/// Small Chunks (50–256 tokens): Best for precision-focused tasks (e.g., Q&A, technical docs) where specific details matter.
/// Medium Chunks (256–1,024 tokens): Ideal for balanced tasks like RAG or contextual search, providing enough context without noise.
/// Large Chunks (1,024–2,048 tokens): Suited for analysis or thematic tasks where broad understanding is key.
///
/// overlap:
/// Add 10–20% overlap for larger chunks (e.g., 50–100 tokens for 512-token chunks) to preserve context across boundaries.
pub fn split_text_into_chunks(
  object_id: &str,
  paragraphs: Vec<String>,
  embedding_model: LocalEmbeddingModel,
  chunk_size: usize,
  overlap: usize,
  source: RAGSource,
) -> Result<Vec<EmbeddedChunk>, FlowyError> {
  if paragraphs.is_empty() {
    return Ok(vec![]);
  }
  let split_contents = group_paragraphs_by_max_content_len(paragraphs, chunk_size, overlap);
  let metadata = json!({
      SOURCE_ID: object_id,
      SOURCE: source.as_str(),
      SOURCE_NAME: source.file_name(),
  });

  let mut seen = std::collections::HashSet::new();
  let mut chunks = Vec::new();

  for (index, content) in split_contents.into_iter().enumerate() {
    let metadata_string = metadata.to_string();
    let combined_data = format!("{}{}", content, metadata_string);
    let consistent_hash = Hasher::oneshot(0, combined_data.as_bytes());
    let fragment_id = format!("{:x}", consistent_hash);
    if seen.insert(fragment_id.clone()) {
      chunks.push(EmbeddedChunk {
        fragment_id,
        object_id: object_id.to_string(),
        content_type: 0,
        content: Some(content),
        embeddings: None,
        metadata: Some(metadata_string),
        fragment_index: index as i32,
        dimension: embedding_model.dimension().size(),
      });
    } else {
      debug!(
        "[Embedding] Duplicate fragment_id detected: {}. This fragment will not be added.",
        fragment_id
      );
    }
  }

  trace!(
    "[Embedding] Created {} chunks for object_id `{}`, chunk_size: {}, overlap: {}",
    chunks.len(),
    object_id,
    chunk_size,
    overlap
  );
  Ok(chunks)
}

fn group_paragraphs_by_max_content_len(
  paragraphs: Vec<String>,
  mut context_size: usize,
  overlap: usize,
) -> Vec<String> {
  if paragraphs.is_empty() {
    return vec![];
  }

  let mut result = Vec::new();
  let mut current = String::with_capacity(context_size.min(4096));

  if overlap > context_size {
    warn!("context_size is smaller than overlap, which may lead to unexpected behavior.");
    context_size = 2 * overlap;
  }

  let chunk_config = ChunkConfig::new(context_size)
    .with_overlap(overlap)
    .unwrap();
  let splitter = TextSplitter::new(chunk_config);

  for paragraph in paragraphs {
    if current.len() + paragraph.len() > context_size {
      if !current.is_empty() {
        result.push(std::mem::take(&mut current));
      }

      if paragraph.len() > context_size {
        let paragraph_chunks = splitter.chunks(&paragraph);
        result.extend(paragraph_chunks.map(String::from));
      } else {
        current.push_str(&paragraph);
      }
    } else {
      // Add paragraph to current chunk
      current.push_str(&paragraph);
    }
  }

  if !current.is_empty() {
    result.push(current);
  }

  result
}
