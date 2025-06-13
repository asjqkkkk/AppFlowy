use collab::preclude::Collab;
use collab_database::database::Database;
use collab_database::error::DatabaseError;
use collab_database::workspace_database::{DatabaseMeta, WorkspaceDatabase};
use lib_infra::async_entry::AsyncEntry;
use std::borrow::{Borrow, BorrowMut};
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{error, trace};

pub struct WorkspaceDatabaseManager {
  body: WorkspaceDatabase,
}

pub type DatabaseEntry = Arc<AsyncEntry<Arc<RwLock<Database>>, String>>;

impl WorkspaceDatabaseManager {
  pub fn open(_object_id: &str, collab: Collab) -> Result<Self, DatabaseError> {
    let body = WorkspaceDatabase::open(collab)?;
    Ok(Self { body })
  }

  pub fn close(&self) {
    self.body.close();
  }

  /// Return the database id with the given view id.
  pub fn get_database_id_with_view_id(&self, view_id: &str) -> Option<String> {
    self
      .body
      .get_database_meta_with_view_id(view_id)
      .map(|record| record.database_id)
  }

  /// Create linked view that shares the same data with the inline view's database
  /// If the inline view is deleted, the reference view will be deleted too.
  pub fn trace_linked_view(&mut self, database_id: &str, view_id: String) {
    self.body.update_database(database_id, |record| {
      if record.linked_views.contains(&view_id) {
        error!("The view is already linked to the database");
      } else {
        trace!("Insert linked view record: {}", view_id);
        record.linked_views.push(view_id.clone());
      }
    });
  }

  pub fn track_database(&mut self, database_id: &str, database_view_ids: Vec<String>) {
    self.body.add_database(database_id, database_view_ids);
  }

  /// Return all the database records.
  pub fn get_all_database_meta(&self) -> Vec<DatabaseMeta> {
    self.body.get_all_database_meta()
  }

  pub fn get_database_meta(&self, database_id: &str) -> Option<DatabaseMeta> {
    self.body.get_database_meta(database_id)
  }
}

impl Borrow<Collab> for WorkspaceDatabaseManager {
  #[inline]
  fn borrow(&self) -> &Collab {
    self.body.borrow()
  }
}

impl BorrowMut<Collab> for WorkspaceDatabaseManager {
  #[inline]
  fn borrow_mut(&mut self) -> &mut Collab {
    self.body.borrow_mut()
  }
}
