use anyhow::anyhow;
use async_trait::async_trait;
use collab::lock::RwLock;
use collab::preclude::ClientID;
use collab_database::database_trait::{DatabaseRowCollabService, DatabaseRowDataVariant};
use collab_database::error::DatabaseError;
use collab_database::rows::{DatabaseRow, RowChangeSender, RowId};
use dashmap::DashMap;
use lib_infra::async_entry::AsyncEntry;
use std::collections::HashMap;
use std::sync::Arc;
use std::time::Duration;
use tracing::error;

pub struct DatabaseRowCollabServiceMiddleware {
  rows: Arc<DashMap<String, DatabaseRowEntry>>,
  inner: Arc<dyn DatabaseRowCollabService>,
}

impl DatabaseRowCollabServiceMiddleware {
  pub fn new(inner: Arc<dyn DatabaseRowCollabService>) -> Self {
    Self {
      rows: Arc::new(Default::default()),
      inner,
    }
  }
}

#[async_trait]
impl DatabaseRowCollabService for DatabaseRowCollabServiceMiddleware {
  async fn database_row_client_id(&self) -> ClientID {
    self.inner.database_row_client_id().await
  }

  async fn create_arc_database_row(
    &self,
    object_id: &str,
    data: DatabaseRowDataVariant,
    sender: Option<RowChangeSender>,
  ) -> Result<Arc<RwLock<DatabaseRow>>, DatabaseError> {
    self
      .inner
      .create_arc_database_row(object_id, data, sender)
      .await
  }

  async fn build_arc_database_row(
    &self,
    object_id: &str,
    data: Option<DatabaseRowDataVariant>,
    sender: Option<RowChangeSender>,
  ) -> Result<Arc<RwLock<DatabaseRow>>, DatabaseError> {
    if let Some(row_entry) = self.rows.get(object_id) {
      if let Some(row) = row_entry.get_resource().await {
        return Ok(row);
      }
    }

    let entry = self
      .rows
      .entry(object_id.to_string())
      .or_insert_with(|| DatabaseRowEntry::new_initializing(object_id.to_string()))
      .clone();

    if let Some(row) = entry.get_resource().await {
      return Ok(row);
    }

    if entry.try_mark_initialization_start().await {
      let row = self
        .inner
        .build_arc_database_row(object_id, data, sender)
        .await?;
      entry.set_resource(row.clone()).await;
      Ok(row)
    } else {
      match entry.wait_for_initialization(Duration::from_secs(10)).await {
        Ok(database) => Ok(database),
        Err(err) => {
          error!("Database initialization failed or timed out: {}", err);
          Err(DatabaseError::Internal(anyhow!(err)))
        },
      }
    }
  }

  async fn batch_build_arc_database_row(
    &self,
    row_ids: &[String],
    sender: Option<RowChangeSender>,
  ) -> Result<HashMap<RowId, Arc<RwLock<DatabaseRow>>>, DatabaseError> {
    self
      .inner
      .batch_build_arc_database_row(row_ids, sender)
      .await
  }
}
type DatabaseRowEntry = AsyncEntry<Arc<RwLock<DatabaseRow>>, String>;
