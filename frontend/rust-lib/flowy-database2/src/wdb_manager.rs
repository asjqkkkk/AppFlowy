use collab::preclude::Collab;
use collab_database::database::{Database, DatabaseContext, DatabaseData};
use collab_database::entity::{CreateDatabaseParams, CreateViewParams};
use collab_database::error::DatabaseError;
use collab_database::workspace_database::{DatabaseCollabService, DatabaseMeta, WorkspaceDatabase};
use std::collections::HashMap;
use lib_infra::async_entry::AsyncEntry;
use std::borrow::{Borrow, BorrowMut};
use std::collections::HashSet;
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::RwLock;
use tracing::{error, trace};

/// A [WorkspaceDatabaseManager] indexes the databases within a workspace.
/// Within a workspace, the view ID is used to identify each database. Therefore, you can use the view_id to retrieve
/// the actual database ID from [WorkspaceDatabaseManager]. Additionally, [WorkspaceDatabaseManager] allows you to obtain a database
/// using its database ID.
///
/// Relation between database ID and view ID:
/// One database ID can have multiple view IDs.
///
pub struct WorkspaceDatabaseManager {
  body: WorkspaceDatabase,
  collab_service: Arc<dyn DatabaseCollabService>,
  /// In memory database entries with their initialization state.
  /// The key is the database id. The entry will be added when the database is opened or created,
  /// and the entry will be removed when the database is deleted or closed.
  database_entries: RwLock<HashMap<String, DatabaseEntry>>,
}

type DatabaseEntry = Arc<AsyncEntry<Arc<RwLock<Database>>, String>>;

impl WorkspaceDatabaseManager {
  pub fn open(
    _object_id: &str,
    collab: Collab,
    collab_service: impl DatabaseCollabService,
  ) -> Result<Self, DatabaseError> {
    let collab_service = Arc::new(collab_service);
    let body = WorkspaceDatabase::open(collab)?;
    Ok(Self {
      body,
      collab_service,
      database_entries: RwLock::new(HashMap::new()),
    })
  }

  pub fn close(&self) {
    self.body.close();
  }

  /// Get the database with the given database id.
  /// Return None if the database does not exist.
  pub async fn get_or_init_database(
    &self,
    database_id: &str,
  ) -> Result<Arc<RwLock<Database>>, DatabaseError> {
    // First, try to get existing entry with read lock
    {
      let entries = self.database_entries.read().await;
      if let Some(entry) = entries.get(database_id) {
        if let Some(database) = entry.get_resource().await {
          trace!("Database already initialized: {}", database_id);
          return Ok(database);
        }
      }
    }

    // Get or create entry with write lock
    let entry = {
      let mut entries = self.database_entries.write().await;
      entries
        .entry(database_id.to_string())
        .or_insert_with(|| Arc::new(AsyncEntry::new_initializing(database_id.to_string())))
        .clone()
    };

    // Check if we already have the database after acquiring entry
    if let Some(database) = entry.get_resource().await {
      trace!("Database already initialized: {}", database_id);
      return Ok(database);
    }

    // Try to start initialization
    if entry.try_mark_initialization_start().await {
      trace!("Initializing database: {}", database_id);
      let context = DatabaseContext::new(self.collab_service.clone());
      match Database::arc_open(database_id, context).await {
        Ok(database) => {
          // Store the database in the entry
          entry.set_resource(database.clone()).await;
          trace!("Database opened and stored: {}", database_id);
          Ok(database)
        },
        Err(err) => {
          error!("Open database failed: {}", err);
          entry.mark_initialization_failed(err.to_string()).await;
          Err(err)
        },
      }
    } else {
      // Another task is initializing, wait for it to complete
      trace!("Waiting for database initialization: {}", database_id);
      match entry.wait_for_initialization(Duration::from_secs(30)).await {
        Ok(database) => {
          trace!("Database initialization completed: {}", database_id);
          Ok(database)
        },
        Err(err) => {
          error!("Database initialization failed or timed out: {}", err);
          Err(DatabaseError::Internal(anyhow::anyhow!(err)))
        },
      }
    }
  }

  /// Return the database id with the given view id.
  /// Multiple views can share the same database.
  pub async fn get_database_with_view_id(&self, view_id: &str) -> Option<Arc<RwLock<Database>>> {
    let database_id = self.get_database_id_with_view_id(view_id)?;
    self.get_or_init_database(&database_id).await.ok()
  }

  /// Return the database id with the given view id.
  pub fn get_database_id_with_view_id(&self, view_id: &str) -> Option<String> {
    self
      .body
      .get_database_meta_with_view_id(view_id)
      .map(|record| record.database_id)
  }

  /// Create database with inline view.
  /// The inline view is the default view of the database.
  /// If the inline view gets deleted, the database will be deleted too.
  /// So the reference views will be deleted too.
  pub async fn create_database(
    &mut self,
    params: CreateDatabaseParams,
  ) -> Result<Arc<RwLock<Database>>, DatabaseError> {
    let context = DatabaseContext::new(self.collab_service.clone());
    let mut linked_views = HashSet::new();
    linked_views.extend(params.views.iter().map(|view| view.view_id.clone()));
    self
      .body
      .add_database(&params.database_id, linked_views.into_iter().collect());

    let database_id = params.database_id.clone();
    let database = Database::create_arc_with_view(params, context).await?;

    let entry = Arc::new(AsyncEntry::new_initializing(database_id.clone()));
    entry.set_resource(database.clone()).await;
    self.database_entries.write().await.insert(database_id, entry);

    Ok(database)
  }

  /// Create linked view that shares the same data with the inline view's database
  /// If the inline view is deleted, the reference view will be deleted too.
  pub async fn create_database_linked_view(
    &mut self,
    params: CreateViewParams,
  ) -> Result<(), DatabaseError> {
    let params = CreateViewParamsValidator::validate(params)?;
    let database = self.get_or_init_database(&params.database_id).await?;
    self.body.update_database(&params.database_id, |record| {
      if record.linked_views.contains(&params.view_id) {
        error!("The view is already linked to the database");
      } else {
        trace!("Insert linked view record: {}", params.view_id);
        record.linked_views.push(params.view_id.clone());
      }
    });

    let mut write_guard = database.write().await;
    write_guard.create_linked_view(params)
  }

  pub async fn close_database(&self, database_id: &str) {
    if let Some(entry) = self.database_entries.write().await.remove(database_id) {
      // Mark the entry for removal to allow cleanup
      tokio::spawn(async move {
        entry.mark_for_removal().await;
      });
    }
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

  /// Duplicate the database that contains the view.
  pub async fn duplicate_database(
    &mut self,
    database_view_id: &str,
    new_database_view_id: &str,
  ) -> Result<Arc<RwLock<Database>>, DatabaseError> {
    let database_data = self.get_database_data(database_view_id).await?;
    let create_database_params = CreateDatabaseParams::from_database_data(
      database_data,
      database_view_id,
      new_database_view_id,
    );
    let database = self.create_database(create_database_params).await?;
    Ok(database)
  }

  /// Get all of the database data using the id of any view in the database
  pub async fn get_database_data(&self, view_id: &str) -> Result<DatabaseData, DatabaseError> {
    if let Some(database) = self.get_database_with_view_id(view_id).await {
      let data = database.read().await.get_database_data().await;
      Ok(data)
    } else {
      Err(DatabaseError::DatabaseNotExist)
    }
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

pub(crate) struct CreateViewParamsValidator;

impl CreateViewParamsValidator {
  pub(crate) fn validate(params: CreateViewParams) -> Result<CreateViewParams, DatabaseError> {
    if params.database_id.is_empty() {
      return Err(DatabaseError::InvalidDatabaseID("database_id is empty"));
    }

    if params.view_id.is_empty() {
      return Err(DatabaseError::InvalidViewID("view_id is empty"));
    }

    Ok(params)
  }
}
