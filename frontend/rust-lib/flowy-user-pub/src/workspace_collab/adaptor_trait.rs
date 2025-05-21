use crate::workspace_collab::adaptor::unindexed_data_form_collab;
use client_api::v2::{ObjectId, WorkspaceId};
use collab::lock::RwLock;
use collab::preclude::Collab;
use collab_entity::CollabType;
use collab_plugins::CollabKVDB;
use flowy_ai_pub::entities::UnindexedData;
use flowy_error::{FlowyError, FlowyResult};
use lib_infra::async_trait::async_trait;
use std::borrow::BorrowMut;
use std::sync::Weak;
use uuid::Uuid;

pub trait WorkspaceCollabUser: Send + Sync {
  fn workspace_id(&self) -> Result<Uuid, FlowyError>;
  fn uid(&self) -> Result<i64, FlowyError>;
  fn device_id(&self) -> Result<String, FlowyError>;

  fn collab_db(&self) -> FlowyResult<Weak<CollabKVDB>>;
}

#[async_trait]
pub trait CollabIndexedData: Send + Sync + 'static {
  async fn get_unindexed_data(&self, collab_type: &CollabType) -> Option<UnindexedData>;
}

#[async_trait]
impl<T> CollabIndexedData for RwLock<T>
where
  T: BorrowMut<Collab> + Send + Sync + 'static,
{
  async fn get_unindexed_data(&self, collab_type: &CollabType) -> Option<UnindexedData> {
    let collab = self.try_read().ok()?;
    unindexed_data_form_collab(collab.borrow(), collab_type)
  }
}

#[async_trait]
pub trait WorkspaceCollabIndexer: Send + Sync {
  async fn index_opened_collab(
    &self,
    workspace_id: WorkspaceId,
    object_id: ObjectId,
    collab_type: CollabType,
  );
}

/// writer interface
#[async_trait]
pub trait EditingCollabDataConsumer: Send + Sync + 'static {
  fn consumer_id(&self) -> String;

  async fn consume_collab(
    &self,
    workspace_id: &Uuid,
    data: UnindexedData,
    object_id: &Uuid,
    collab_type: CollabType,
  ) -> Result<bool, FlowyError>;

  async fn did_delete_collab(
    &self,
    workspace_id: &Uuid,
    object_id: &Uuid,
  ) -> Result<(), FlowyError>;
}
