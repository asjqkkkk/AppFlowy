use crate::chat_file::ChatLocalFileStorage;
use crate::local_ai::chat::retriever::{AFRetriever, MultipleSourceRetrieverStore};
use async_trait::async_trait;
use futures::future::join_all;
use langchain_rust::schemas::Document;
use std::error::Error;
use std::sync::Arc;
use tracing::{debug, error, trace};
use uuid::Uuid;

pub struct MultipleSourceRetriever {
  workspace_id: Uuid,
  chat_id: Uuid,
  vector_stores: Vec<Arc<dyn MultipleSourceRetrieverStore>>,
  num_docs: usize,
  rag_ids: Vec<String>,
  full_search: bool,
  score_threshold: f32,
  local_file_storage: Option<Arc<ChatLocalFileStorage>>,
}

impl MultipleSourceRetriever {
  pub fn new<V: Into<Arc<dyn MultipleSourceRetrieverStore>>>(
    workspace_id: Uuid,
    chat_id: Uuid,
    vector_stores: Vec<V>,
    rag_ids: Vec<String>,
    num_docs: usize,
    score_threshold: f32,
    file_storage: Option<Arc<ChatLocalFileStorage>>,
  ) -> Self {
    MultipleSourceRetriever {
      workspace_id,
      chat_id,
      vector_stores: vector_stores.into_iter().map(|v| v.into()).collect(),
      num_docs,
      rag_ids,
      full_search: false,
      score_threshold,
      local_file_storage: file_storage,
    }
  }
}

#[async_trait]
impl AFRetriever for MultipleSourceRetriever {
  async fn get_rag_ids(&self) -> Vec<String> {
    let mut rag_ids = self.rag_ids.to_vec();
    if let Some(local_file_storage) = self.local_file_storage.as_ref() {
      let chat_id = self.chat_id.to_string();
      if let Ok(files) = local_file_storage.get_files_for_chat(&chat_id).await {
        // If there are files associated with the chat, add the chat_id to rag_ids
        if !files.is_empty() {
          debug!(
            "[VectorStore] Found local files for chat {}, adding to rag_ids",
            chat_id
          );
          rag_ids.push(chat_id);
        }
      }
    }

    rag_ids
  }

  fn set_rag_ids(&mut self, new_rag_ids: Vec<String>) {
    self.rag_ids = new_rag_ids;
  }

  async fn retrieve_documents(&self, query: &str) -> Result<Vec<Document>, Box<dyn Error>> {
    let rag_ids = self.get_rag_ids().await;
    trace!(
      "[VectorStore] filters: {:?}, retrieving documents for query: {}",
      rag_ids, query,
    );

    // Create futures for each vector store search
    let search_futures = self
      .vector_stores
      .iter()
      .map(|vector_store| {
        let vector_store = vector_store.clone();
        let query = query.to_string();
        let num_docs = self.num_docs;
        let full_search = self.full_search;
        let cloned_rag_ids = rag_ids.clone();
        let workspace_id = self.workspace_id;
        let score_threshold = self.score_threshold;

        async move {
          vector_store
            .read_documents(
              &workspace_id,
              &query,
              num_docs,
              &cloned_rag_ids,
              score_threshold,
              full_search,
            )
            .await
            .map(|docs| (vector_store.retriever_name(), docs))
        }
      })
      .collect::<Vec<_>>();

    let search_results = join_all(search_futures).await;
    let mut results = Vec::new();
    for result in search_results {
      if let Ok((retriever_name, docs)) = result {
        trace!(
          "[VectorStore] {} found {} results, scores: {:?}",
          retriever_name,
          docs.len(),
          docs.iter().map(|doc| doc.score).collect::<Vec<_>>()
        );
        results.extend(docs);
      } else {
        error!(
          "[VectorStore] Failed to retrieve documents: {}",
          result.unwrap_err()
        );
      }
    }

    Ok(results)
  }
}
