use crate::embeddings::indexer::LocalEmbeddingModel;
use crate::local_ai::chat::llm::LocalLLMController;
use flowy_ai_pub::entities::EmbeddingDimension;
use flowy_error::FlowyResult;
use ollama_rs::generation::embeddings::GenerateEmbeddingsResponse;
use ollama_rs::generation::embeddings::request::GenerateEmbeddingsRequest;
use std::sync::Arc;

#[derive(Debug, Clone)]
pub enum Embedder {
  Ollama(Arc<LocalLLMController>),
}

impl Embedder {
  pub async fn embed(
    &self,
    request: GenerateEmbeddingsRequest,
  ) -> FlowyResult<GenerateEmbeddingsResponse> {
    match self {
      Embedder::Ollama(ollama) => ollama.embed(request).await,
    }
  }

  pub fn model(&self) -> LocalEmbeddingModel {
    match self {
      Embedder::Ollama(ollama) => ollama.embed_model(),
    }
  }

  pub fn dimension(&self) -> EmbeddingDimension {
    match self {
      Embedder::Ollama(ollama) => ollama.embed_dimension(),
    }
  }
}
