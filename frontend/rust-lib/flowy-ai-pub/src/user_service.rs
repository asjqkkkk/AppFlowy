use flowy_error::{FlowyError, FlowyResult};
use flowy_sqlite::DBConnection;
use lib_infra::async_trait::async_trait;
use std::path::PathBuf;
use uuid::Uuid;

#[async_trait]
pub trait AIUserService: Send + Sync + 'static {
  fn user_id(&self) -> Result<i64, FlowyError>;
  async fn is_anon(&self) -> Result<bool, FlowyError>;
  async fn validate_vault(&self) -> FlowyResult<ValidateVaultResult>;
  fn workspace_id(&self) -> Result<Uuid, FlowyError>;
  fn sqlite_connection(&self, uid: i64) -> Result<DBConnection, FlowyError>;
  fn application_root_dir(&self) -> Result<PathBuf, FlowyError>;
  fn user_data_dir(&self) -> Result<PathBuf, FlowyError>;
}

#[derive(Clone, Default)]
pub struct ValidateVaultResult {
  pub is_vault: bool,
  pub is_vault_enabled: bool,
}

impl ValidateVaultResult {
  pub fn can_use_local_ai(&self) -> bool {
    if self.is_vault {
      self.is_vault_enabled
    } else {
      true
    }
  }
}
