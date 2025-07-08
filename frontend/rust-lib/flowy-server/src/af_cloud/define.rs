use client_api::v2::ConnectState;
use collab::preclude::ClientID;
use collab_plugins::CollabKVDB;
use flowy_error::{FlowyError, FlowyResult};
use flowy_sqlite::DBConnection;
use flowy_user_pub::entities::{CheckVaultResult, WorkspaceType};
use futures_util::stream::BoxStream;
use lib_infra::async_trait::async_trait;
use std::path::PathBuf;
use std::sync::Weak;
use uuid::Uuid;

pub const USER_SIGN_IN_URL: &str = "sign_in_url";
pub const USER_UUID: &str = "uuid";
pub const USER_EMAIL: &str = "email";
pub const USER_DEVICE_ID: &str = "device_id";

pub trait LoggedWorkspace: Send + Sync {
  fn subscribe_ws_state(&self) -> FlowyResult<BoxStream<'static, ConnectState>>;

  fn ws_state(&self) -> FlowyResult<ConnectState>;
}

/// Represents a user that is currently using the server.
#[async_trait]
pub trait LoggedUser: Send + Sync {
  /// different user might return different workspace id.
  fn workspace_id(&self) -> FlowyResult<Uuid>;
  fn workspace_type(&self) -> FlowyResult<WorkspaceType>;

  fn user_id(&self) -> FlowyResult<i64>;
  async fn validate_vault(&self) -> FlowyResult<CheckVaultResult>;
  async fn is_anon(&self) -> FlowyResult<bool>;

  fn get_sqlite_db(&self, uid: i64) -> Result<DBConnection, FlowyError>;

  fn get_collab_db(&self, uid: i64) -> Result<Weak<CollabKVDB>, FlowyError>;

  fn application_root_dir(&self) -> Result<PathBuf, FlowyError>;

  fn collab_client_id(&self, workspace_id: &Uuid) -> ClientID;
}
