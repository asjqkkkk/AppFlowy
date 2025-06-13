use collab::core::collab::default_client_id;
use collab::preclude::ClientID;
use collab_plugins::CollabKVDB;
use flowy_document::manager::{DocumentManager, DocumentUserService};
use flowy_document_pub::cloud::DocumentCloudService;
use flowy_error::FlowyError;
use flowy_storage_pub::storage::StorageService;
use flowy_user::services::authenticate_user::AuthenticateUser;
use flowy_user_pub::workspace_collab::adaptor::WorkspaceCollabAdaptor;
use std::sync::{Arc, Weak};
use tracing::warn;
use uuid::Uuid;

pub struct DocumentDepsResolver();
impl DocumentDepsResolver {
  pub fn resolve(
    authenticate_user: Weak<AuthenticateUser>,
    collab_builder: Weak<WorkspaceCollabAdaptor>,
    cloud_service: Arc<dyn DocumentCloudService>,
    storage_service: Weak<dyn StorageService>,
  ) -> Arc<DocumentManager> {
    let user_service: Arc<dyn DocumentUserService> =
      Arc::new(DocumentUserImpl(authenticate_user.clone()));
    Arc::new(DocumentManager::new(
      user_service.clone(),
      collab_builder,
      cloud_service,
      storage_service,
    ))
  }
}

struct DocumentUserImpl(Weak<AuthenticateUser>);
impl DocumentUserService for DocumentUserImpl {
  fn user_id(&self) -> Result<i64, FlowyError> {
    self
      .0
      .upgrade()
      .ok_or(FlowyError::internal().with_context("Unexpected error: UserSession is None"))?
      .user_id()
  }

  fn device_id(&self) -> Result<String, FlowyError> {
    self
      .0
      .upgrade()
      .ok_or(FlowyError::internal().with_context("Unexpected error: UserSession is None"))?
      .device_id()
  }

  fn workspace_id(&self) -> Result<Uuid, FlowyError> {
    self
      .0
      .upgrade()
      .ok_or(FlowyError::internal().with_context("Unexpected error: UserSession is None"))?
      .workspace_id()
  }

  fn collab_db(&self, uid: i64) -> Result<Weak<CollabKVDB>, FlowyError> {
    self
      .0
      .upgrade()
      .ok_or(FlowyError::internal().with_context("Unexpected error: UserSession is None"))?
      .get_collab_db(uid)
  }

  fn collab_client_id(&self, workspace_id: &Uuid) -> ClientID {
    match self.0.upgrade() {
      None => {
        warn!("Failed to get collab client id, using default client id",);
        default_client_id()
      },
      Some(user) => user.collab_client_id(workspace_id),
    }
  }
}
