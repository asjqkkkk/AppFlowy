use async_trait::async_trait;
use collab::core::collab::CollabOptions;
use collab::core::origin::CollabOrigin;
use collab::entity::EncodedCollab;
use collab::lock::RwLock;
use collab::preclude::{ClientID, Collab};
use collab_database::database_trait::{DatabaseRowCollabService, DatabaseRowDataVariant};
use collab_database::error::DatabaseError;
use collab_database::rows::{DatabaseRow, RowChangeSender, RowId};
use collab_entity::CollabType;
use collab_plugins::CollabKVDB;
use dashmap::DashMap;
use std::collections::HashMap;
use std::sync::Arc;

pub struct ImportDatabaseRowCollabService {
  pub db: Arc<CollabKVDB>,
  pub client_id: ClientID,
  pub cache: Arc<DashMap<RowId, Arc<RwLock<DatabaseRow>>>>,
}

#[async_trait]
impl DatabaseRowCollabService for ImportDatabaseRowCollabService {
  async fn database_row_client_id(&self) -> ClientID {
    self.client_id
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
    let row_id = RowId::from(object_id);
    if let Some(cached_row) = self.cache.get(&row_id) {
      return Ok(cached_row.clone());
    }

    let data = data
      .ok_or_else(|| {
        DatabaseError::Internal(anyhow::anyhow!(
          "Data for row with object_id {} is required",
          object_id
        ))
      })?
      .into_encode_collab(self.client_id);

    let collab_type = CollabType::DatabaseRow;
    let collab = build_collab(self.client_id, object_id, collab_type, data).await?;
    let database_row = DatabaseRow::open(RowId::from(object_id), collab, sender)?;
    let arc_row = Arc::new(RwLock::new(database_row));
    self.cache.insert(row_id, arc_row.clone());
    Ok(arc_row)
  }

  async fn batch_build_arc_database_row(
    &self,
    _row_ids: &[String],
    _sender: Option<RowChangeSender>,
    _auto_fetch: bool,
  ) -> Result<HashMap<RowId, Arc<RwLock<DatabaseRow>>>, DatabaseError> {
    Err(DatabaseError::Internal(anyhow::anyhow!("unimplemented")))
  }
}

async fn build_collab(
  client_id: ClientID,
  object_id: &str,
  _object_type: CollabType,
  encoded_collab: EncodedCollab,
) -> Result<Collab, DatabaseError> {
  let options =
    CollabOptions::new(object_id.to_string(), client_id).with_data_source(encoded_collab.into());
  Ok(Collab::new_with_options(CollabOrigin::Empty, options).unwrap())
}
