use crate::ai_tool::text_split::{RAGSource, split_text_into_chunks};
use crate::embeddings::embedder::Embedder;
use crate::embeddings::indexer::{Indexer, LocalEmbeddingModel};
use flowy_ai_pub::entities::EmbeddedChunk;
use flowy_error::FlowyError;
use lib_infra::async_trait::async_trait;
use ollama_rs::generation::embeddings::request::{EmbeddingsInput, GenerateEmbeddingsRequest};
use tracing::{debug, error, warn};
use uuid::Uuid;

pub struct DocumentIndexer;

#[async_trait]
impl Indexer for DocumentIndexer {
  fn create_embedded_chunks_from_text(
    &self,
    object_id: Uuid,
    paragraphs: Vec<String>,
    model: LocalEmbeddingModel,
  ) -> Result<Vec<EmbeddedChunk>, FlowyError> {
    if paragraphs.is_empty() {
      warn!(
        "[Embedding] No paragraphs found in document `{}`. Skipping embedding.",
        object_id
      );

      return Ok(vec![]);
    }
    split_text_into_chunks(
      &object_id.to_string(),
      paragraphs,
      model,
      1000,
      200,
      RAGSource::AppFlowyDocument,
    )
  }

  async fn embed(
    &self,
    embedder: &Embedder,
    mut chunks: Vec<EmbeddedChunk>,
  ) -> Result<Vec<EmbeddedChunk>, FlowyError> {
    let mut valid_indices = Vec::new();
    for (i, chunk) in chunks.iter().enumerate() {
      if let Some(ref content) = chunk.content {
        if !content.is_empty() {
          valid_indices.push(i);
        }
      }
    }

    if valid_indices.is_empty() {
      return Ok(vec![]);
    }

    let mut contents = Vec::with_capacity(valid_indices.len());
    for &i in &valid_indices {
      contents.push(chunks[i].content.as_ref().unwrap().to_owned());
    }

    debug!(
      "[Embedding] Requesting embeddings for content: {:?}",
      contents
    );
    let request = GenerateEmbeddingsRequest::new(
      embedder.model().name().to_string(),
      EmbeddingsInput::Multiple(contents),
    );
    let resp = embedder.embed(request).await?;
    if resp.embeddings.len() != valid_indices.len() {
      error!(
        "[Embedding] requested {} embeddings, received {} embeddings",
        valid_indices.len(),
        resp.embeddings.len()
      );
      return Err(FlowyError::internal().with_context(format!(
        "Mismatch in number of embeddings requested and received: {} vs {}",
        valid_indices.len(),
        resp.embeddings.len()
      )));
    }

    for (index, embedding) in resp.embeddings.into_iter().enumerate() {
      let chunk_idx = valid_indices[index];
      chunks[chunk_idx].embeddings = Some(embedding);
    }

    Ok(chunks)
  }
}
