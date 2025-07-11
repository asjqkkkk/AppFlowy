use crate::cloud::CollabType;
use crate::cloud::workspace_dto::ViewIcon;
use std::fmt::Display;
use twox_hash::xxhash64::Hasher;
use uuid::Uuid;
pub const RAG_IDS: &str = "rag_ids";
pub const SOURCE_ID: &str = "id";
pub const WORKSPACE_ID: &str = "workspace_id";
pub const SOURCE: &str = "source";
pub const SOURCE_NAME: &str = "name";
pub struct EmbeddingRecord {
  pub workspace_id: Uuid,
  pub object_id: Uuid,
  pub chunks: Vec<EmbeddedChunk>,
}

impl Display for EmbeddingRecord {
  fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
    write!(
      f,
      "EmbeddingRecord(workspace:{}, object_id: {}, chunks: {})",
      self.workspace_id,
      self.object_id,
      self.chunks.len()
    )
  }
}

#[derive(Debug, Clone, Default)]
pub struct UnindexedCollabMetadata {
  pub name: Option<String>,
  pub icon: Option<ViewIcon>,
}

#[derive(Debug, Clone)]
pub struct UnindexedCollab {
  pub workspace_id: Uuid,
  pub object_id: Uuid,
  pub collab_type: CollabType,
  pub data: Option<UnindexedData>,
  pub metadata: UnindexedCollabMetadata,
}

impl UnindexedCollab {
  pub fn is_empty(&self) -> bool {
    self.data.is_none() || self.data.as_ref().unwrap().is_empty()
  }
}

#[derive(Debug, Clone)]
pub enum UnindexedData {
  Text(String),
  Paragraphs(Vec<String>),
}

impl UnindexedData {
  pub fn is_empty(&self) -> bool {
    match self {
      UnindexedData::Text(text) => text.is_empty(),
      UnindexedData::Paragraphs(paragraphs) => paragraphs.is_empty(),
    }
  }

  pub fn into_string(&self) -> String {
    match self {
      UnindexedData::Text(text) => text.clone(),
      UnindexedData::Paragraphs(paragraphs) => paragraphs.join("\n"),
    }
  }

  pub fn content_hash(&self) -> String {
    match self {
      UnindexedData::Text(text) => {
        let h = Hasher::oneshot(0, text.as_bytes());
        format!("{:016x}", h)
      },
      UnindexedData::Paragraphs(paragraphs) => {
        let combined = paragraphs.join("");
        let h = Hasher::oneshot(0, combined.as_bytes());
        format!("{:016x}", h)
      },
    }
  }
}

#[derive(Debug, Clone)]
pub struct EmbeddedChunk {
  pub fragment_id: String,
  pub object_id: String,
  pub content_type: i32,
  pub content: Option<String>,
  pub metadata: Option<String>,
  pub fragment_index: i32,
  pub embedder_type: i32,
  pub embeddings: Option<Vec<f32>>,
}

#[derive(Debug, Clone)]
pub struct SearchResult {
  pub oid: Uuid,
  pub content: String,
  pub metadata: Option<serde_json::Value>,
  pub score: f32,
}

impl Display for SearchResult {
  fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
    write!(
      f,
      "SearchResult(oid: {}, content: {}, score: {})",
      self.oid, self.content, self.score
    )
  }
}
