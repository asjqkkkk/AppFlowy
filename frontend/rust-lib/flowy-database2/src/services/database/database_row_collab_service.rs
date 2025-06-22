use crate::collab_service::DatabaseCollabServiceImpl;
use anyhow::anyhow;
use async_trait::async_trait;
use collab::lock::RwLock;
use collab::preclude::ClientID;
use collab_database::database_trait::{
  DatabaseCollabService, DatabaseRowCollabService, DatabaseRowDataVariant,
};
use collab_database::error::DatabaseError;
use collab_database::rows::{DatabaseRow, RowChangeSender, RowId};
use collab_entity::CollabType;
use dashmap::DashMap;
use futures::future::join_all;
use lib_infra::async_entry::AsyncEntry;
use std::collections::HashMap;
use std::sync::Arc;
use std::time::Duration;
use tracing::{error, trace};
use uuid::Uuid;

pub struct DatabaseRowCollabServiceMiddleware {
  rows: Arc<DashMap<String, DatabaseRowEntry>>,
  inner: Arc<DatabaseCollabServiceImpl>,
}

impl DatabaseRowCollabServiceMiddleware {
  pub(crate) fn new(inner: Arc<DatabaseCollabServiceImpl>) -> Self {
    Self {
      rows: Arc::new(Default::default()),
      inner,
    }
  }
}

#[async_trait]
impl DatabaseRowCollabService for DatabaseRowCollabServiceMiddleware {
  async fn database_row_client_id(&self) -> ClientID {
    self.inner.database_client_id().await
  }

  async fn create_arc_database_row(
    &self,
    object_id: &str,
    data: DatabaseRowDataVariant,
    sender: Option<RowChangeSender>,
  ) -> Result<Arc<RwLock<DatabaseRow>>, DatabaseError> {
    self
      .build_arc_database_row(object_id, Some(data), sender)
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

    if entry.should_initialize().await {
      let client_id = self.database_row_client_id().await;
      let collab_type = CollabType::DatabaseRow;
      let data = data.map(|v| v.into_encode_collab(client_id));

      trace!(
        "[Database]: build arc database row:{}, collab_type: {:?}, data: {:#?}",
        object_id, collab_type, data
      );

      let source = self
        .inner
        .get_data_source(object_id, collab_type, data)
        .await?;
      let collab = self
        .inner
        .build_collab(object_id, collab_type, source)
        .await?;
      let database_row = DatabaseRow::open(RowId::from(object_id), collab, sender)?;
      let row = Arc::new(RwLock::new(database_row));
      let object_id = Uuid::parse_str(object_id)?;
      self
        .inner
        .collab_builder()
        .map_err(|err| DatabaseError::Internal(err.into()))?
        .cache_collab(object_id, collab_type, row.clone())
        .await?;

      entry.set_resource(row.clone()).await;
      drop(entry);

      Ok(row)
    } else {
      match entry.wait_for_initialization(Duration::from_secs(10)).await {
        Ok(database) => Ok(database),
        Err(err) => {
          error!(
            "Database Row:{} initialization failed or timed out: {}",
            object_id, err
          );
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
    let encoded_collab_by_id = self
      .inner
      .batch_get_encode_collab(row_ids.to_vec(), CollabType::DatabaseRow)
      .await?;

    // Prepare concurrent tasks to initialize database rows
    let futures = encoded_collab_by_id
      .into_iter()
      .map(|(row_id, encoded_collab)| async {
        let row_id = RowId::from(row_id);
        let database_row = self
          .build_arc_database_row(
            &row_id,
            Some(DatabaseRowDataVariant::EncodedCollab(encoded_collab)),
            sender.clone(),
          )
          .await?;
        Ok::<_, DatabaseError>((row_id, database_row))
      });

    // Execute the tasks concurrently and collect them into a HashMap
    let uncached_rows: HashMap<RowId, Arc<RwLock<DatabaseRow>>> = join_all(futures)
      .await
      .into_iter()
      .collect::<Result<HashMap<_, _>, _>>()?;

    Ok(uncached_rows)
  }
}
type DatabaseRowEntry = AsyncEntry<Arc<RwLock<DatabaseRow>>, String>;
