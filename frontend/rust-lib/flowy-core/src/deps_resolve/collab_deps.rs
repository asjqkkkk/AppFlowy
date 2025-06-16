use collab_plugins::CollabKVDB;
use flowy_error::{FlowyError, FlowyResult};
use flowy_sqlite::{prelude::*, schema::collab_snapshot};
use flowy_user::services::authenticate_user::AuthenticateUser;
use flowy_user_pub::workspace_collab::adaptor_trait::WorkspaceCollabUser;
use std::sync::{Arc, Weak};
use uuid::Uuid;

#[derive(PartialEq, Clone, Debug, Queryable, Identifiable, Insertable)]
#[diesel(table_name = collab_snapshot)]
pub(crate) struct CollabSnapshotRow {
  pub(crate) id: String,
  object_id: String,
  title: String,
  desc: String,
  collab_type: String,
  pub(crate) timestamp: i64,
  pub(crate) data: Vec<u8>,
}

pub struct WorkspaceCollabIntegrateImpl(pub Weak<AuthenticateUser>);

impl WorkspaceCollabIntegrateImpl {
  fn upgrade_user(&self) -> Result<Arc<AuthenticateUser>, FlowyError> {
    let user = self
      .0
      .upgrade()
      .ok_or(FlowyError::internal().with_context("Unexpected error: UserSession is None"))?;
    Ok(user)
  }
}

impl WorkspaceCollabUser for WorkspaceCollabIntegrateImpl {
  fn workspace_id(&self) -> Result<Uuid, FlowyError> {
    let workspace_id = self.upgrade_user()?.workspace_id()?;
    Ok(workspace_id)
  }

  fn uid(&self) -> Result<i64, FlowyError> {
    let uid = self.upgrade_user()?.user_id()?;
    Ok(uid)
  }

  fn device_id(&self) -> Result<String, FlowyError> {
    Ok(self.upgrade_user()?.user_config.device_id.clone())
  }

  fn collab_db(&self) -> FlowyResult<Weak<CollabKVDB>> {
    let user = self.upgrade_user()?;
    let uid = user.user_id()?;
    user.get_collab_db(uid)
  }
}
