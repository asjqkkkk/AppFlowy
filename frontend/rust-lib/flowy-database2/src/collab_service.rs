use crate::DatabaseUser;
use anyhow::anyhow;
use async_trait::async_trait;
use collab::core::collab::{CollabOptions, DataSource, default_client_id};
use collab::core::origin::CollabOrigin;
use collab::entity::EncodedCollab;
use collab::lock::RwLock;
use collab::preclude::{ClientID, Collab};
use collab_database::database::{Database, DatabaseBody, DatabaseContext, default_database_collab};
use collab_database::database_trait::{
  CollabPersistenceImpl, DatabaseCollabPersistenceService, DatabaseCollabService,
  DatabaseDataVariant, EncodeCollabByOid,
};
use collab_database::error::DatabaseError;
use collab_entity::CollabType;
use collab_plugins::CollabKVDB;
use collab_plugins::local_storage::kv::KVTransactionDB;
use collab_plugins::local_storage::kv::doc::CollabKVAction;
use flowy_database_pub::ChangedCollab;
use flowy_database_pub::cloud::DatabaseCloudService;
use flowy_error::FlowyError;
use flowy_user_pub::workspace_collab::adaptor::WorkspaceCollabAdaptor;
use rayon::iter::IntoParallelRefIterator;
use rayon::prelude::*;
use std::collections::HashMap;
use std::str::FromStr;
use std::sync::{Arc, Weak};
use tokio::sync::broadcast;
use tracing::{error, info, instrument, trace};
use uuid::Uuid;

#[derive(Clone)]
pub(crate) struct DatabaseCollabServiceImpl {
  is_local_user: bool,
  user: Arc<dyn DatabaseUser>,
  workspace_collab_adaptor: Weak<WorkspaceCollabAdaptor>,
  persistence: Arc<dyn DatabaseCollabPersistenceService>,
  cloud_service: Arc<dyn DatabaseCloudService>,
}

impl DatabaseCollabServiceImpl {
  pub(crate) fn new(
    is_local_user: bool,
    user: Arc<dyn DatabaseUser>,
    workspace_collab_adaptor: Weak<WorkspaceCollabAdaptor>,
    cloud_service: Arc<dyn DatabaseCloudService>,
  ) -> Self {
    let persistence = DatabasePersistenceImpl { user: user.clone() };
    Self {
      is_local_user,
      user,
      workspace_collab_adaptor,
      persistence: Arc::new(persistence),
      cloud_service,
    }
  }

  pub async fn subscribe_changed_collab(
    &self,
  ) -> Result<broadcast::Receiver<ChangedCollab>, FlowyError> {
    let collab_builder = self.collab_builder()?;
    collab_builder.subscribe_changed_collab().await
  }

  pub(crate) fn collab_builder(&self) -> Result<Arc<WorkspaceCollabAdaptor>, FlowyError> {
    self
      .workspace_collab_adaptor
      .upgrade()
      .ok_or_else(|| FlowyError::internal().with_context("Collab builder is not initialized"))
  }

  async fn get_encode_collab(
    &self,
    object_id: &Uuid,
    object_ty: CollabType,
  ) -> Result<Option<EncodedCollab>, DatabaseError> {
    let workspace_id = self
      .user
      .workspace_id()
      .map_err(|e| DatabaseError::Internal(e.into()))?;
    trace!("[Database]: fetch {}:{} from remote", object_id, object_ty);
    let encode_collab = self
      .cloud_service
      .get_database_encode_collab(object_id, object_ty, &workspace_id)
      .await
      .map_err(|err| DatabaseError::Internal(err.into()))?;
    Ok(encode_collab)
  }

  pub(crate) async fn batch_get_encode_collab(
    &self,
    mut object_ids: Vec<String>,
    collab_type: CollabType,
  ) -> Result<EncodeCollabByOid, DatabaseError> {
    if object_ids.is_empty() {
      return Ok(EncodeCollabByOid::new());
    }

    let mut encoded_collab_by_id = EncodeCollabByOid::new();
    // 1. Collect local disk collabs into a HashMap
    let local_disk_encoded_collab: HashMap<String, EncodedCollab> = object_ids
      .par_iter()
      .filter_map(|object_id| {
        self
          .persistence
          .get_encoded_collab(object_id, collab_type)
          .map(|encoded_collab| (object_id.clone(), encoded_collab))
      })
      .collect();
    trace!(
      "[Database]: load {} database row from local disk",
      local_disk_encoded_collab.len()
    );

    object_ids.retain(|object_id| !local_disk_encoded_collab.contains_key(object_id));
    for (k, v) in local_disk_encoded_collab {
      encoded_collab_by_id.insert(k, v);
    }

    if !object_ids.is_empty() {
      let object_ids = object_ids
        .into_iter()
        .flat_map(|v| Uuid::from_str(&v).ok())
        .collect::<Vec<_>>();

      let workspace_id = self
        .user
        .workspace_id()
        .map_err(|err| DatabaseError::Internal(err.into()))?;
      let updates = self
        .cloud_service
        .batch_get_database_encode_collab(object_ids, collab_type, &workspace_id)
        .await
        .map_err(|err| DatabaseError::Internal(err.into()))?;

      let remote_collabs: EncodeCollabByOid = updates
        .into_iter()
        .map(|(k, v)| (k.to_string(), v))
        .collect();

      trace!(
        "[Database]: load {} database row from remote",
        remote_collabs.len()
      );
      for (k, v) in remote_collabs {
        encoded_collab_by_id.insert(k, v);
      }
    }

    Ok(encoded_collab_by_id)
  }

  pub(crate) async fn get_data_source(
    &self,
    object_id: &str,
    collab_type: CollabType,
    encoded_collab: Option<EncodedCollab>,
  ) -> Result<DataSource, DatabaseError> {
    if encoded_collab.is_none()
      && self
        .persistence
        .is_collab_exist(object_id.to_string().as_str())
    {
      return Ok(
        CollabPersistenceImpl {
          persistence: Some(self.persistence.clone()),
        }
        .into(),
      );
    }

    let object_id = Uuid::parse_str(object_id)?;
    match encoded_collab {
      None => {
        info!(
          "build collab: fetch {}:{} from remote, is_new:{}",
          collab_type,
          object_id,
          encoded_collab.is_none(),
        );
        match self.get_encode_collab(&object_id, collab_type).await {
          Ok(Some(encode_collab)) => {
            info!(
              "build collab: {}:{} with remote encode collab, {} bytes",
              collab_type,
              object_id,
              encode_collab.doc_state.len()
            );
            Ok(DataSource::from(encode_collab))
          },
          Ok(None) => {
            if self.is_local_user {
              info!(
                "build collab: {}:{} with empty encode collab",
                collab_type, object_id
              );
              Ok(
                CollabPersistenceImpl {
                  persistence: Some(self.persistence.clone()),
                }
                .into(),
              )
            } else {
              Err(DatabaseError::RecordNotFound)
            }
          },
          Err(err) => {
            if !matches!(err, DatabaseError::ActionCancelled) {
              error!("build collab: failed to get encode collab: {}", err);
            }
            Err(err)
          },
        }
      },
      Some(encoded_collab) => {
        info!(
          "build collab: {}:{} with new encode collab, {} bytes",
          collab_type,
          object_id,
          encoded_collab.doc_state.len()
        );
        Ok(encoded_collab.into())
      },
    }
  }

  #[instrument(level = "trace", skip_all, err)]
  pub(crate) async fn build_collab<T: Into<DataSourceOrCollab>>(
    &self,
    object_id: &str,
    collab_type: CollabType,
    data: T,
  ) -> Result<Collab, DatabaseError> {
    let data: DataSourceOrCollab = data.into();
    let workspace_id = self
      .user
      .workspace_id()
      .map_err(|err| DatabaseError::Internal(err.into()))?;

    let object_uuid = Uuid::parse_str(object_id)?;
    let collab_builder = self
      .collab_builder()
      .map_err(|err| DatabaseError::Internal(err.into()))?;

    let mut collab = match data {
      DataSourceOrCollab::Collab(collab) => collab,
      DataSourceOrCollab::DataSource(source) => {
        collab_builder
          .build_collab_with_source(object_uuid, collab_type, source)
          .await?
      },
    };

    collab_builder
      .bind_collab(workspace_id, object_uuid, collab_type, &mut collab)
      .await?;

    Ok(collab)
  }
}

enum DataSourceOrCollab {
  Collab(Collab),
  DataSource(DataSource),
}

impl From<DataSource> for DataSourceOrCollab {
  fn from(source: DataSource) -> Self {
    DataSourceOrCollab::DataSource(source)
  }
}

impl From<Collab> for DataSourceOrCollab {
  fn from(collab: Collab) -> Self {
    DataSourceOrCollab::Collab(collab)
  }
}

impl From<EncodedCollab> for DataSourceOrCollab {
  fn from(encoded_collab: EncodedCollab) -> Self {
    DataSourceOrCollab::DataSource(DataSource::from(encoded_collab))
  }
}

#[async_trait]
impl DatabaseCollabService for DatabaseCollabServiceImpl {
  async fn database_client_id(&self) -> ClientID {
    match self.workspace_collab_adaptor.upgrade() {
      None => default_client_id(),
      Some(b) => b.client_id().await.unwrap_or(default_client_id()),
    }
  }

  #[instrument(level = "trace", skip_all, err)]
  async fn build_arc_database(
    &self,
    object_id: &str,
    _is_new: bool,
    data: Option<DatabaseDataVariant>,
    context: DatabaseContext,
  ) -> Result<Arc<RwLock<Database>>, DatabaseError> {
    let database = self.build_database(object_id, false, data, context).await?;
    let database = Arc::new(RwLock::new(database));
    let object_id = Uuid::parse_str(object_id)?;
    self
      .collab_builder()
      .map_err(|err| DatabaseError::Internal(err.into()))?
      .cache_collab(object_id, CollabType::Database, database.clone())
      .await?;
    Ok(database)
  }

  #[instrument(level = "trace", skip_all, err)]
  async fn build_database(
    &self,
    object_id: &str,
    _is_new: bool,
    data: Option<DatabaseDataVariant>,
    context: DatabaseContext,
  ) -> Result<Database, DatabaseError> {
    let client_id = self.database_client_id().await;
    let collab_type = CollabType::Database;
    let collab_service = context.database_collab_service.clone();
    let (body, collab) = match data {
      None => {
        let source = self.get_data_source(object_id, collab_type, None).await?;
        let collab = self.build_collab(object_id, collab_type, source).await?;
        DatabaseBody::open(collab, context)?
      },
      Some(data) => match data {
        DatabaseDataVariant::Params(params) => {
          let database_id = params.database_id.clone();
          let (body, collab) =
            default_database_collab(&database_id, client_id, Some(params), context.clone()).await?;
          let collab = self.build_collab(object_id, collab_type, collab).await?;
          (body, collab)
        },
        DatabaseDataVariant::EncodedCollab(data) => {
          let collab = self.build_collab(object_id, collab_type, data).await?;
          DatabaseBody::open(collab, context)?
        },
      },
    };

    Ok(Database {
      collab,
      body,
      collab_service,
    })
  }

  async fn build_workspace_database_collab(
    &self,
    object_id: &str,
    encoded_collab: Option<EncodedCollab>,
  ) -> Result<Collab, DatabaseError> {
    let collab_type = CollabType::WorkspaceDatabase;
    let data_source = self
      .get_data_source(object_id, collab_type, encoded_collab)
      .await?;
    self.build_collab(object_id, collab_type, data_source).await
  }

  async fn get_collabs(
    &self,
    object_ids: Vec<String>,
    collab_type: CollabType,
  ) -> Result<EncodeCollabByOid, DatabaseError> {
    self.batch_get_encode_collab(object_ids, collab_type).await
  }

  fn persistence(&self) -> Option<Arc<dyn DatabaseCollabPersistenceService>> {
    Some(self.persistence.clone())
  }
}

pub struct DatabasePersistenceImpl {
  user: Arc<dyn DatabaseUser>,
}

impl DatabasePersistenceImpl {
  fn workspace_id(&self) -> Result<Uuid, DatabaseError> {
    let workspace_id = self
      .user
      .workspace_id()
      .map_err(|err| DatabaseError::Internal(err.into()))?;
    Ok(workspace_id)
  }

  fn get_workspace_db_context(&self) -> Result<(Uuid, i64, Arc<CollabKVDB>), DatabaseError> {
    let workspace_id = self
      .user
      .workspace_id()
      .map_err(|err| DatabaseError::Internal(err.into()))?;
    let uid = self
      .user
      .user_id()
      .map_err(|err| DatabaseError::Internal(err.into()))?;
    let db = self
      .user
      .collab_db(uid)
      .map_err(|err| DatabaseError::Internal(err.into()))?
      .upgrade()
      .ok_or_else(|| {
        DatabaseError::Internal(anyhow!("Failed to upgrade database weak reference"))
      })?;

    Ok((workspace_id, uid, db))
  }
}

impl DatabaseCollabPersistenceService for DatabasePersistenceImpl {
  fn load_collab(&self, collab: &mut Collab) {
    let result = self
      .user
      .user_id()
      .map(|uid| (uid, self.user.collab_db(uid).map(|weak| weak.upgrade())));

    if let Ok(workspace_id) = self.user.workspace_id() {
      if let Ok((uid, Ok(Some(collab_db)))) = result {
        let object_id = collab.object_id().to_string();
        let db_read = collab_db.read_txn();
        if !db_read.is_exist(uid, workspace_id.to_string().as_str(), &object_id) {
          trace!(
            "[Database]: collab:{} not exist in local storage",
            object_id
          );
          return;
        }

        trace!("[Database]: start loading collab:{} from disk", object_id);
        let mut txn = collab.transact_mut();
        match db_read.load_doc_with_txn(
          uid,
          workspace_id.to_string().as_str(),
          &object_id,
          &mut txn,
        ) {
          Ok(update_count) => {
            trace!(
              "[Database]: did load collab:{}, update_count:{}",
              object_id, update_count
            );
          },
          Err(err) => {
            if !err.is_record_not_found() {
              error!("[Database]: load collab:{} failed:{}", object_id, err);
            }
          },
        }
      }
    }
  }

  fn upsert_collab(
    &self,
    object_id: &str,
    encoded_collab: EncodedCollab,
  ) -> Result<(), DatabaseError> {
    let (workspace_id, uid, db) = self.get_workspace_db_context()?;

    let db_write = db.write_txn();
    let _ = db_write.upsert_doc_with_doc_state(
      uid,
      &workspace_id.to_string(),
      object_id,
      encoded_collab.state_vector.to_vec(),
      encoded_collab.doc_state.to_vec(),
    );
    db_write
      .commit_transaction()
      .map_err(|err| DatabaseError::Internal(err.into()))?;
    Ok(())
  }

  fn get_encoded_collab(&self, object_id: &str, collab_type: CollabType) -> Option<EncodedCollab> {
    let workspace_id = self.user.workspace_id().ok()?;
    let uid = self.user.user_id().ok()?;
    let db = self.user.collab_db(uid).ok()?.upgrade()?;
    let read_txn = db.read_txn();
    if !read_txn.is_exist(uid, workspace_id.to_string().as_str(), object_id) {
      return None;
    }

    let client_id = self.user.collab_client_id(&workspace_id);
    let options = CollabOptions::new(object_id.to_string(), client_id);
    let mut collab = Collab::new_with_options(CollabOrigin::Empty, options).ok()?;
    let mut txn = collab.transact_mut();
    let _ = read_txn.load_doc_with_txn(uid, workspace_id.to_string().as_str(), object_id, &mut txn);
    drop(txn);

    collab
      .encode_collab_v1(|collab| collab_type.validate_require_data(collab))
      .ok()
  }

  fn delete_collab(&self, object_id: &str) -> Result<(), DatabaseError> {
    let workspace_id = self.workspace_id()?.to_string();
    let uid = self
      .user
      .user_id()
      .map_err(|err| DatabaseError::Internal(err.into()))?;
    if let Ok(Some(collab_db)) = self.user.collab_db(uid).map(|weak| weak.upgrade()) {
      let write_txn = collab_db.write_txn();
      write_txn
        .delete_doc(uid, workspace_id.as_str(), object_id)
        .unwrap();
      write_txn
        .commit_transaction()
        .map_err(|err| DatabaseError::Internal(anyhow!("failed to commit transaction: {}", err)))?;
    }
    Ok(())
  }

  fn is_collab_exist(&self, object_id: &str) -> bool {
    match self.user.workspace_id() {
      Ok(workspace_id) => {
        match self
          .user
          .user_id()
          .map_err(|err| DatabaseError::Internal(err.into()))
        {
          Ok(uid) => {
            if let Ok(Some(collab_db)) = self.user.collab_db(uid).map(|weak| weak.upgrade()) {
              let read_txn = collab_db.read_txn();
              return read_txn.is_exist(uid, workspace_id.to_string().as_str(), object_id);
            }
            false
          },
          Err(_) => false,
        }
      },
      Err(_) => false,
    }
  }
}
