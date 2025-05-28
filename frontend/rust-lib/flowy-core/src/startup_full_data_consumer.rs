use crate::startup_full_data_provider::FullIndexedDataConsumer;
use collab_entity::CollabType;
use collab_folder::{IconType, ViewIcon};
use flowy_ai_pub::entities::UnindexedCollab;
use flowy_error::{FlowyError, FlowyResult};
use flowy_search_pub::tantivy_state::DocumentTantivyState;
use flowy_search_pub::tantivy_state_init::get_or_init_document_tantivy_state;
use lib_infra::async_trait::async_trait;
use std::path::PathBuf;
use std::sync::{Arc, Weak};
use tokio::sync::RwLock;
use uuid::Uuid;

#[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
pub struct EmbeddingFullIndexConsumer;

#[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
#[async_trait]
impl FullIndexedDataConsumer for EmbeddingFullIndexConsumer {
  fn consumer_id(&self) -> String {
    "embedding_full_index_consumer".to_string()
  }

  async fn consume_indexed_data(&self, _uid: i64, data: &UnindexedCollab) -> FlowyResult<()> {
    if !matches!(data.collab_type, CollabType::Document) {
      return Ok(());
    }

    if data.is_empty() {
      return Ok(());
    }

    let scheduler = flowy_ai::embeddings::context::EmbedContext::shared().get_scheduler()?;
    scheduler.index_collab(data.clone()).await?;
    Ok(())
  }
}

/// -----------------------------------------------------
/// Full‐index consumer holds only a Weak reference:
/// -----------------------------------------------------
pub struct SearchFullIndexConsumer {
  workspace_id: Uuid,
  state: Weak<RwLock<DocumentTantivyState>>,
}

impl SearchFullIndexConsumer {
  pub fn new(workspace_id: &Uuid, data_path: PathBuf) -> FlowyResult<Self> {
    let strong = get_or_init_document_tantivy_state(*workspace_id, data_path)?;
    Ok(Self {
      workspace_id: *workspace_id,
      state: Arc::downgrade(&strong),
    })
  }
}

#[async_trait]
impl FullIndexedDataConsumer for SearchFullIndexConsumer {
  fn consumer_id(&self) -> String {
    "search_full_index_consumer".into()
  }

  async fn consume_indexed_data(&self, _uid: i64, data: &UnindexedCollab) -> FlowyResult<()> {
    if self.workspace_id != data.workspace_id {
      return Ok(());
    }

    let strong = self
      .state
      .upgrade()
      .ok_or_else(|| FlowyError::internal().with_context("Tantivy state dropped"))?;
    let object_id = data.object_id.to_string();

    let content = data.data.clone().map(|v| v.into_string());
    strong.write().await.add_document(
      &object_id,
      content,
      data.metadata.name.clone(),
      data.metadata.icon.clone().map(|v| ViewIcon {
        ty: IconType::from(v.ty as u8),
        value: v.value,
      }),
    )?;
    Ok(())
  }
}
