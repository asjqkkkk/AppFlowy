#![allow(unused_variables)]

use crate::af_cloud::define::LoggedUser;
use crate::local_server::util::default_encode_collab_for_collab_type;
use client_api::v2::CollabKVActionExt;
use collab::core::collab::{CollabOptions, default_client_id};
use collab::core::origin::CollabOrigin;
use collab::entity::EncodedCollab;
use collab::preclude::Collab;
use collab_entity::CollabType;
use collab_plugins::CollabKVDB;
use collab_plugins::local_storage::kv::KVTransactionDB;
use collab_plugins::local_storage::kv::doc::CollabKVAction;
use flowy_ai_pub::cloud::{CreateCollabParams, QueryCollab};
use flowy_database_pub::cloud::{DatabaseCloudService, DatabaseSnapshot, EncodeCollabByOid};
use flowy_error::{ErrorCode, FlowyError, FlowyResult};
use lib_infra::async_trait::async_trait;
use std::sync::Arc;
use uuid::Uuid;

pub(crate) struct LocalServerDatabaseCloudServiceImpl {
  pub logged_user: Arc<dyn LoggedUser>,
}

impl LocalServerDatabaseCloudServiceImpl {
  fn db(&self) -> FlowyResult<Arc<CollabKVDB>> {
    let uid = self.logged_user.user_id()?;
    let db = self.logged_user.get_collab_db(uid)?;

    db.upgrade()
      .ok_or_else(|| FlowyError::internal().with_context("Collab database is not available"))
  }
}

#[async_trait]
impl DatabaseCloudService for LocalServerDatabaseCloudServiceImpl {
  async fn get_database_encode_collab(
    &self,
    object_id: &Uuid,
    collab_type: CollabType,
    workspace_id: &Uuid,
  ) -> Result<Option<EncodedCollab>, FlowyError> {
    let uid = self.logged_user.user_id()?;
    let object_id = object_id.to_string();
    let client_id = self.logged_user.collab_client_id(workspace_id);
    default_encode_collab_for_collab_type(uid, &object_id, collab_type, client_id)
      .await
      .map(Some)
      .or_else(|err| {
        if matches!(err.code, ErrorCode::NotSupportYet) {
          Ok(None)
        } else {
          Err(err)
        }
      })
  }

  async fn create_database_encode_collab(
    &self,
    object_id: &Uuid,
    collab_type: CollabType,
    workspace_id: &Uuid,
    encoded_collab: EncodedCollab,
  ) -> Result<(), FlowyError> {
    let uid = self.logged_user.user_id()?;
    let db = self.db()?;
    let write = db.write_txn();
    write
      .upsert_doc_with_doc_state(
        uid,
        &workspace_id.to_string(),
        &object_id.to_string(),
        encoded_collab.state_vector.to_vec(),
        encoded_collab.doc_state.to_vec(),
      )
      .map_err(|e| {
        FlowyError::internal().with_context(format!("Failed to create collab: {}", e))
      })?;
    write
      .commit_transaction()
      .map_err(|err| FlowyError::internal().with_context(err))?;
    Ok(())
  }

  async fn batch_get_database_encode_collab(
    &self,
    objects: Vec<QueryCollab>,
    workspace_id: &Uuid,
  ) -> Result<EncodeCollabByOid, FlowyError> {
    let uid = self.logged_user.user_id()?;
    let db = self.db()?;
    let read = db.read_txn();
    let client_id = read
      .client_id(workspace_id)
      .unwrap_or_else(|_| default_client_id());
    let workspace_id = workspace_id.to_string();

    let mut value = EncodeCollabByOid::default();
    for object in objects {
      let object_id = object.object_id.to_string();
      let options = CollabOptions::new(object.object_id.to_string(), client_id);
      let mut collab = Collab::new_with_options(CollabOrigin::Empty, options).map_err(|err| {
        FlowyError::internal().with_context(format!("Failed to create collab: {}", err))
      })?;
      let mut txn = collab.transact_mut();
      read
        .load_doc_with_txn(uid, &workspace_id, &object_id, &mut txn)
        .map_err(|e| {
          FlowyError::internal().with_context(format!("Failed to load collab: {}", e))
        })?;
      drop(txn);

      let encoded_collab = collab.encode_collab_v1(|_| Ok::<_, FlowyError>(()))?;
      value.insert(object.object_id, encoded_collab);
    }
    Ok(value)
  }

  async fn batch_create_database_encode_collab(
    &self,
    workspace_id: &Uuid,
    collabs: Vec<CreateCollabParams>,
  ) -> Result<(), FlowyError> {
    let uid = self.logged_user.user_id()?;
    let db = self.db()?;
    let workspace_id = workspace_id.to_string();

    tokio::task::spawn_blocking(move || {
      let write = db.write_txn();
      for params in collabs {
        if write.is_exist(uid, &workspace_id, &params.object_id.to_string()) {
          continue;
        }

        let encoded_collab =
          EncodedCollab::decode_from_bytes(&params.encoded_collab_v1).map_err(|err| {
            FlowyError::internal().with_context(format!("Failed to decode collab: {}", err))
          })?;
        write
          .upsert_doc_with_doc_state(
            uid,
            &workspace_id,
            &params.object_id.to_string(),
            encoded_collab.state_vector.to_vec(),
            encoded_collab.doc_state.to_vec(),
          )
          .map_err(|e| {
            FlowyError::internal().with_context(format!("Failed to create collab: {}", e))
          })?;
      }
      write
        .commit_transaction()
        .map_err(|err| FlowyError::internal().with_context(err))?;
      Ok::<_, FlowyError>(())
    })
    .await??;
    Ok(())
  }

  async fn get_database_collab_object_snapshots(
    &self,
    object_id: &Uuid,
    limit: usize,
  ) -> Result<Vec<DatabaseSnapshot>, FlowyError> {
    Ok(vec![])
  }
}
