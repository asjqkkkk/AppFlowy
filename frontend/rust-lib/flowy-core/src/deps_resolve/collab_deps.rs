use collab_plugins::CollabKVDB;
use diesel::SqliteConnection;
use flowy_error::{FlowyError, FlowyResult};
use flowy_sqlite::{
  prelude::*,
  schema::{collab_snapshot, collab_snapshot::dsl},
};
use flowy_user::services::authenticate_user::AuthenticateUser;
use flowy_user_pub::workspace_collab::adaptor::WorkspaceCollabUser;
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

pub struct CollabSnapshotMeta {
  pub id: String,
  pub object_id: String,
  pub timestamp: i64,
}

pub(crate) struct CollabSnapshotSql;
impl CollabSnapshotSql {
  pub(crate) fn get_all_snapshots(
    object_id: &str,
    conn: &mut SqliteConnection,
  ) -> Result<Vec<CollabSnapshotMeta>, FlowyError> {
    let results = collab_snapshot::table
      .filter(collab_snapshot::object_id.eq(object_id))
      .select((
        collab_snapshot::id,
        collab_snapshot::object_id,
        collab_snapshot::timestamp,
      ))
      .load::<(String, String, i64)>(conn)
      .expect("Error loading collab_snapshot");

    // Map the results to CollabSnapshotMeta
    let snapshots: Vec<CollabSnapshotMeta> = results
      .into_iter()
      .map(|(id, object_id, timestamp)| CollabSnapshotMeta {
        id,
        object_id,
        timestamp,
      })
      .collect();

    Ok(snapshots)
  }

  pub(crate) fn get_snapshot(
    object_id: &str,
    conn: &mut SqliteConnection,
  ) -> Option<CollabSnapshotRow> {
    let sql = dsl::collab_snapshot
      .filter(dsl::id.eq(object_id))
      .into_boxed();

    sql
      .order(dsl::timestamp.desc())
      .first::<CollabSnapshotRow>(conn)
      .ok()
  }

  #[allow(dead_code)]
  pub(crate) fn delete(
    object_id: &str,
    snapshot_ids: Option<Vec<String>>,
    conn: &mut SqliteConnection,
  ) -> Result<(), FlowyError> {
    let mut sql = diesel::delete(dsl::collab_snapshot).into_boxed();
    sql = sql.filter(dsl::object_id.eq(object_id));

    if let Some(snapshot_ids) = snapshot_ids {
      tracing::trace!(
        "[{}] Delete snapshot: {}:{:?}",
        std::any::type_name::<Self>(),
        object_id,
        snapshot_ids
      );
      sql = sql.filter(dsl::id.eq_any(snapshot_ids));
    }

    let affected_row = sql.execute(conn)?;
    tracing::trace!(
      "[{}] Delete {} rows",
      std::any::type_name::<Self>(),
      affected_row
    );
    Ok(())
  }
}

pub(crate) struct WorkspaceCollabIntegrateImpl(pub Weak<AuthenticateUser>);

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
