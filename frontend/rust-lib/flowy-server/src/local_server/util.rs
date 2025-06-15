use collab::core::collab::CollabOptions;
use collab::core::origin::CollabOrigin;
use collab::entity::EncodedCollab;
use collab::preclude::{ClientID, Collab};
use collab_database::database::{DatabaseContext, default_database_collab};
use collab_database::database_trait::NoPersistenceDatabaseCollabService;
use collab_database::error::DatabaseError;
use collab_database::workspace_database::default_workspace_database_data;
use collab_document::document_data::default_document_collab_data;
use collab_entity::CollabType;
use collab_user::core::default_user_awareness_data;
use flowy_error::{FlowyError, FlowyResult};
use std::sync::Arc;

pub async fn default_encode_collab_for_collab_type(
  _uid: i64,
  object_id: &str,
  collab_type: CollabType,
  client_id: ClientID,
) -> FlowyResult<EncodedCollab> {
  match collab_type {
    CollabType::Document => {
      let encode_collab = default_document_collab_data(object_id, client_id)?;
      Ok(encode_collab)
    },
    CollabType::Database => {
      let collab_service = Arc::new(NoPersistenceDatabaseCollabService::new(client_id));
      default_database_data(
        object_id,
        client_id,
        DatabaseContext::new(collab_service.clone(), collab_service),
      )
      .await
      .map_err(Into::into)
    },
    CollabType::WorkspaceDatabase => Ok(default_workspace_database_data(object_id, client_id)),
    CollabType::Folder => {
      // let collab = Collab::new_with_origin(CollabOrigin::Empty, object_id, vec![], false);
      // let workspace = Workspace::new(object_id.to_string(), "".to_string(), uid);
      // let folder_data = FolderData::new(workspace);
      // let folder = Folder::create(uid, collab, None, folder_data);
      // let data = folder.encode_collab_v1(|c| {
      //   collab_type
      //     .validate_require_data(c)
      //     .map_err(|err| FlowyError::invalid_data().with_context(err))?;
      //   Ok::<_, FlowyError>(())
      // })?;
      // Ok(data)
      Err(FlowyError::not_support().with_context("Can not create default folder"))
    },
    CollabType::DatabaseRow => {
      Err(FlowyError::not_support().with_context("Can not create default database row"))
    },
    CollabType::UserAwareness => Ok(default_user_awareness_data(object_id, client_id)),
    CollabType::Unknown => {
      let options = CollabOptions::new(object_id.to_string(), client_id);
      let collab = Collab::new_with_options(CollabOrigin::Empty, options)?;
      let data = collab.encode_collab_v1(|_| Ok::<_, FlowyError>(()))?;
      Ok(data)
    },
  }
}

async fn default_database_data(
  database_id: &str,
  client_id: ClientID,
  context: DatabaseContext,
) -> Result<EncodedCollab, DatabaseError> {
  let collab = default_database_collab(database_id, client_id, None, context)
    .await?
    .1;
  collab.encode_collab_v1(|_collab| Ok::<_, DatabaseError>(()))
}
