use crate::EventIntegrationTest;
use bytes::Bytes;
use flowy_error::FlowyResult;
use flowy_search::entities::{SearchResponsePB, SearchStatePB};
use flowy_search::services::manager::SearchType;
use futures::{Sink, StreamExt};
use lib_infra::util::timestamp;
use std::convert::TryFrom;
use std::pin::Pin;
use std::sync::{Arc, Mutex};
use std::task::{Context, Poll};
use std::time::{Duration, Instant};
use uuid::Uuid;

impl EventIntegrationTest {
  pub async fn perform_search(&self, query: &str) -> Vec<FlowyResult<SearchResponsePB>> {
    let sink = CollectingSink::new();
    let search_id = timestamp();

    self
      .search_manager
      .perform_search_with_sink(query.to_string(), sink.clone(), search_id)
      .await;

    // Parse the collected results
    let mut results = Vec::new();
    for data in sink.get_results() {
      if let Ok(search_state) = SearchStatePB::try_from(Bytes::from(data)) {
        if let Some(response) = search_state.response {
          results.push(Ok(response));
        }
      }
    }

    results
  }

  // Helper function to perform search and collect results
  pub async fn perform_search_with_workspace(
    &self,
    query: &str,
    workspace_id: &Uuid,
  ) -> Vec<FlowyResult<SearchResponsePB>> {
    let search_handler = self
      .search_manager
      .get_handler(SearchType::DocumentLocal)
      .unwrap();

    let stream = search_handler
      .perform_search(query.to_string(), workspace_id)
      .await;

    stream.collect().await
  }

  pub async fn search_until_get_result(
    &self,
    query: &str,
    workspace_id: &Uuid,
    document_name: &str,
    timeout_secs: u64,
  ) -> Vec<FlowyResult<SearchResponsePB>> {
    let start_time = Instant::now();
    let timeout = Duration::from_secs(timeout_secs);
    let mut result = Vec::new();

    while start_time.elapsed() < timeout {
      result = self
        .perform_search_with_workspace(query, workspace_id)
        .await;

      if let Some(Ok(search_result)) = result.first() {
        if let Some(local) = &search_result.local_search {
          if local
            .items
            .iter()
            .any(|item| item.display_name.contains(document_name))
          {
            break;
          }
        }
      }

      tokio::time::sleep(Duration::from_secs(2)).await;
    }

    result
  }

  pub async fn wait_until_full_indexing_finish(&self) {
    let mut rx = self
      .user_manager
      .app_life_cycle
      .read()
      .await
      .subscribe_full_indexed_finish()
      .unwrap();
    let _ = rx.changed().await;
  }
}

#[derive(Clone)]
struct CollectingSink {
  results: Arc<Mutex<Vec<Vec<u8>>>>,
}

impl CollectingSink {
  fn new() -> Self {
    Self {
      results: Arc::new(Mutex::new(Vec::new())),
    }
  }

  fn get_results(&self) -> Vec<Vec<u8>> {
    self.results.lock().unwrap().clone()
  }
}

impl Sink<Vec<u8>> for CollectingSink {
  type Error = String;

  fn poll_ready(self: Pin<&mut Self>, _cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
    Poll::Ready(Ok(()))
  }

  fn start_send(self: Pin<&mut Self>, item: Vec<u8>) -> Result<(), Self::Error> {
    self.results.lock().unwrap().push(item);
    Ok(())
  }

  fn poll_flush(self: Pin<&mut Self>, _cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
    Poll::Ready(Ok(()))
  }

  fn poll_close(self: Pin<&mut Self>, _cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
    Poll::Ready(Ok(()))
  }
}
