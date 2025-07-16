use crate::embeddings::document_indexer::DocumentIndexer;
use crate::embeddings::embedder::Embedder;
use flowy_ai_pub::cloud::CollabType;
use flowy_ai_pub::entities::{EmbeddedChunk, EmbeddingDimension};
use flowy_error::FlowyError;
use lib_infra::async_trait::async_trait;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fmt::Display;
use std::sync::Arc;
use tracing::warn;
use uuid::Uuid;

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq, Hash)]
pub enum LocalEmbeddingModel {
  Dim768 { model_name: String },
  Dim2560 { model_name: String },
}

pub fn supported_dimensions() -> Vec<usize> {
  vec![
    EmbeddingDimension::Dim768.size(),
    EmbeddingDimension::Dim2560.size(),
  ]
}

impl Default for LocalEmbeddingModel {
  fn default() -> Self {
    LocalEmbeddingModel::Dim768 {
      model_name: "nomic-embed-text".to_string(),
    }
  }
}

impl Display for LocalEmbeddingModel {
  fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
    write!(f, "{}", self.name())
  }
}

impl From<(String, usize)> for LocalEmbeddingModel {
  fn from((model_name, dimension): (String, usize)) -> Self {
    match dimension {
      768 => LocalEmbeddingModel::Dim768 { model_name },
      2560 => LocalEmbeddingModel::Dim2560 { model_name },
      _ => {
        warn!(
          "Unsupported embedding model:{} with dimension: {}. Defaulting to 768.",
          model_name, dimension
        );
        LocalEmbeddingModel::Dim768 { model_name }
      },
    }
  }
}

impl LocalEmbeddingModel {
  pub fn name(&self) -> &str {
    match self {
      LocalEmbeddingModel::Dim768 { model_name } => model_name.as_str(),
      LocalEmbeddingModel::Dim2560 { model_name } => model_name.as_str(),
    }
  }

  pub fn dimension(&self) -> EmbeddingDimension {
    match self {
      LocalEmbeddingModel::Dim768 { .. } => {
        // https://ollama.com/library/nomic-embed-text/blobs/970aa74c0a90
        EmbeddingDimension::Dim768
      },
      LocalEmbeddingModel::Dim2560 { .. } => {
        // https://huggingface.co/Qwen/Qwen3-Embedding-8B
        EmbeddingDimension::Dim2560
      },
    }
  }
}

#[async_trait]
pub trait Indexer: Send + Sync {
  fn create_embedded_chunks_from_text(
    &self,
    object_id: Uuid,
    paragraphs: Vec<String>,
    model: LocalEmbeddingModel,
  ) -> Result<Vec<EmbeddedChunk>, FlowyError>;

  async fn embed(
    &self,
    embedder: &Embedder,
    chunks: Vec<EmbeddedChunk>,
  ) -> Result<Vec<EmbeddedChunk>, FlowyError>;
}

/// A structure responsible for resolving different [Indexer] types for different [CollabType]s,
/// including access permission checks for the specific workspaces.
pub struct IndexerProvider {
  indexer_cache: HashMap<CollabType, Arc<dyn Indexer>>,
}

impl IndexerProvider {
  pub fn new() -> Arc<Self> {
    let mut cache: HashMap<CollabType, Arc<dyn Indexer>> = HashMap::new();
    cache.insert(CollabType::Document, Arc::new(DocumentIndexer));
    Arc::new(Self {
      indexer_cache: cache,
    })
  }

  /// Returns indexer for a specific type of [Collab] object.
  /// If collab of given type is not supported or workspace it belongs to has indexing disabled,
  /// returns `None`.
  pub fn indexer_for(&self, collab_type: CollabType) -> Option<Arc<dyn Indexer>> {
    self.indexer_cache.get(&collab_type).cloned()
  }
}
