use crate::local_ai::chat::retriever::{AFRetriever, RetrieverStore};
use async_trait::async_trait;
use flowy_ai_pub::persistence::select_chat_file_ids;
use flowy_ai_pub::user_service::AIUserService;
use flowy_error::{FlowyError, FlowyResult};
use flowy_sqlite::DBConnection;
use futures::future::join_all;
use langchain_rust::schemas::Document;
use std::error::Error;
use std::sync::{Arc, Weak};
use tracing::{debug, error, trace};
use uuid::Uuid;

/// A retriever that queries multiple vector stores and distributes results based on weights.
pub struct MultipleSourceRetriever {
  workspace_id: Uuid,
  chat_id: Uuid,
  vector_stores: Vec<Arc<dyn RetrieverStore>>,
  max_num_docs: usize,
  rag_ids: Vec<String>,
  score_threshold: f32,
  user_service: Option<Weak<dyn AIUserService>>,
}

impl MultipleSourceRetriever {
  pub fn new<V: Into<Arc<dyn RetrieverStore>>>(
    workspace_id: Uuid,
    chat_id: Uuid,
    vector_stores: Vec<V>,
    rag_ids: Vec<String>,
    user_service: Option<Weak<dyn AIUserService>>,
  ) -> Self {
    MultipleSourceRetriever {
      workspace_id,
      chat_id,
      vector_stores: vector_stores.into_iter().map(|v| v.into()).collect(),
      max_num_docs: 5,
      rag_ids,
      score_threshold: 0.1,
      user_service,
    }
  }

  fn user_service(&self) -> FlowyResult<Arc<dyn AIUserService>> {
    self
      .user_service
      .as_ref()
      .and_then(|v| v.upgrade())
      .ok_or_else(|| FlowyError::ref_drop().with_context("User service is not available"))
  }

  fn sqlite_connection(&self) -> FlowyResult<DBConnection> {
    let user_service = self.user_service()?;
    let uid = user_service.user_id()?;
    user_service.sqlite_connection(uid)
  }
}

#[async_trait]
impl AFRetriever for MultipleSourceRetriever {
  async fn get_rag_ids(&self) -> Vec<String> {
    let mut rag_ids = self.rag_ids.to_vec();
    if let Ok(db_connection) = self.sqlite_connection() {
      if let Ok(file_ids) = select_chat_file_ids(db_connection, &self.chat_id.to_string()) {
        if !file_ids.is_empty() {
          // If there are file IDs associated with the chat, add them to rag_ids
          debug!(
            "[VectorStore] Found files for chat {}, adding to rag_ids",
            self.chat_id
          );
          rag_ids.extend(file_ids);
          rag_ids.push(self.chat_id.to_string());
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
        let num_docs = self.max_num_docs;
        let cloned_rag_ids = rag_ids.clone();
        let workspace_id = self.workspace_id;
        let score_threshold = self.score_threshold;
        let chat_id = self.chat_id;

        async move {
          vector_store
            .read_documents(
              &workspace_id,
              &chat_id,
              &query,
              num_docs,
              &cloned_rag_ids,
              score_threshold,
            )
            .await
            .map(|docs| (vector_store.retriever_name(), vector_store.weights(), docs))
        }
      })
      .collect::<Vec<_>>();

    let search_results = join_all(search_futures).await;
    let mut weighted_results: Vec<(usize, Document)> = Vec::new();
    for result in search_results {
      if let Ok((retriever_name, weight, docs)) = result {
        trace!(
          "[VectorStore] {} (weight: {}) found {} results, scores: {:?}",
          retriever_name,
          weight,
          docs.len(),
          docs.iter().map(|doc| doc.score).collect::<Vec<_>>()
        );

        // Add each document with its retriever's weight
        for doc in docs {
          weighted_results.push((weight, doc));
        }
      } else {
        error!(
          "[VectorStore] Failed to retrieve documents: {}",
          result.unwrap_err()
        );
      }
    }

    // Sort by weight (ascending) and then by score (descending)
    weighted_results.sort_by(|a, b| {
      match a.0.cmp(&b.0) {
        std::cmp::Ordering::Equal => {
          // If weights are equal, sort by score in descending order
          b.1
            .score
            .partial_cmp(&a.1.score)
            .unwrap_or(std::cmp::Ordering::Equal)
        },
        other => other,
      }
    });

    // Take only the first num_docs results
    let results: Vec<Document> = weighted_results
      .into_iter()
      .take(self.max_num_docs)
      .map(|(_, doc)| doc)
      .collect();

    trace!(
      "[VectorStore] Returning {} documents after sorting and limiting",
      results.len()
    );

    Ok(results)
  }
}
