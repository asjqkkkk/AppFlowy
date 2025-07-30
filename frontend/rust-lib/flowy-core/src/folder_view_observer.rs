use collab_folder::ViewChange;
use flowy_search_pub::entities::FolderViewObserver;
use flowy_search_pub::tantivy_state::DocumentTantivyState;
use lib_infra::async_trait::async_trait;
use std::sync::Weak;
use tokio::sync::RwLock;
use uuid::Uuid;

pub struct FolderViewObserverImpl {
  state: Weak<RwLock<DocumentTantivyState>>,
}

impl FolderViewObserverImpl {
  pub fn new(_workspace_id: &Uuid, state: Weak<RwLock<DocumentTantivyState>>) -> Self {
    Self { state }
  }
}

#[async_trait]
impl FolderViewObserver for FolderViewObserverImpl {
  async fn set_observer_rx(&self, mut rx: tokio::sync::broadcast::Receiver<ViewChange>) {
    let state = self.state.clone();
    tokio::spawn(async move {
      while let Ok(msg) = rx.recv().await {
        let state = match state.upgrade() {
          Some(state) => state,
          None => {
            return;
          },
        };

        match msg {
          ViewChange::DidCreateView { view } => {
            let _ = state.write().await.add_document_metadata(
              &view.id,
              Some(view.name.clone()),
              view.icon.clone(),
            );
          },
          ViewChange::DidUpdate { view } => {
            let _ = state.write().await.add_document_metadata(
              &view.id,
              Some(view.name.clone()),
              view.icon.clone(),
            );
          },
          ViewChange::DidDeleteView { views } => {
            let ids: Vec<String> = views.iter().map(|v| v.id.clone()).collect();
            let _ = state.write().await.delete_documents(&ids);
          },
        }
      }
    });
  }
}
