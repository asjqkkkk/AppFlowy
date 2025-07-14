use async_trait::async_trait;
use flowy_error::FlowyResult;
use futures::Stream;
pub use langchain_rust::schemas::Document as LangchainDocument;
use serde::{Deserialize, Serialize};
use std::error::Error;
use std::path::Path;
use std::pin::Pin;
use uuid::Uuid;

pub mod multi_source_retriever;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum EmbedFileProgress {
  StartProcessing {
    file_name: String,
  },
  ReadingFile {
    progress: f32,
    current_page: Option<usize>,
    total_pages: Option<usize>,
  },
  ReadingFileDetails {
    details: String,
  },
  Completed {
    content: String,
  },
  Error {
    message: String,
  },
}

#[async_trait]
pub trait AFRetriever: Send + Sync + 'static {
  async fn get_rag_ids(&self) -> Vec<String>;
  fn set_rag_ids(&mut self, new_rag_ids: Vec<String>);

  async fn retrieve_documents(&self, query: &str)
  -> Result<Vec<LangchainDocument>, Box<dyn Error>>;
}

#[async_trait]
pub trait AFEmbedder: Send + Sync + 'static {
  async fn embed_file(
    &self,
    file_path: &Path,
  ) -> FlowyResult<Pin<Box<dyn Stream<Item = FlowyResult<EmbedFileProgress>> + Send>>>;
}

#[async_trait]
pub trait RetrieverStore: Send + Sync {
  fn retriever_name(&self) -> &'static str;

  fn weights(&self) -> usize;

  #[allow(clippy::too_many_arguments)]
  async fn read_documents(
    &self,
    workspace_id: &Uuid,
    chat_id: &Uuid,
    query: &str,
    limit: usize,
    rag_ids: &[String],
    score_threshold: f32,
  ) -> FlowyResult<Vec<LangchainDocument>>;
}
