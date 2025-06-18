use arc_swap::ArcSwapOption;
use collab::lock::RwLock;
use collab::preclude::ClientID;
use collab_database::database::{Database, DatabaseContext, DatabaseData};
use collab_database::database_trait::DatabaseCollabService;
use collab_database::entity::{CreateDatabaseParams, CreateViewParams};
use collab_database::fields::translate_type_option::TranslateTypeOption;
use collab_database::rows::RowId;
use collab_database::template::csv::CSVTemplate;
use collab_database::views::DatabaseLayout;
use collab_database::workspace_database::{DatabaseMeta, WorkspaceDatabase};
use collab_entity::CollabType;
use collab_plugins::CollabKVDB;
use dashmap::DashMap;
use std::collections::{HashMap, HashSet};
use std::str::FromStr;
use std::sync::{Arc, Weak};
use std::time::Duration;
use tracing::{debug, error, info, instrument, trace};

use flowy_database_pub::cloud::{
  DatabaseAIService, DatabaseCloudService, SummaryRowContent, TranslateItem, TranslateRowContent,
};
use flowy_error::{FlowyError, FlowyResult, internal_error};

use crate::collab_service::DatabaseCollabServiceImpl;
use crate::entities::{DatabaseLayoutPB, DatabaseSnapshotPB, FieldType, RowMetaPB};
use crate::services::cell::stringify_cell;
use crate::services::database::{DatabaseEditor, DatabaseRowCollabServiceMiddleware};
use crate::services::database_view::DatabaseLayoutDepsResolver;
use crate::services::field_settings::default_field_settings_by_layout_map;
use crate::services::share::csv::{CSVFormat, CSVImporter, ImportResult};
use flowy_user_pub::workspace_collab::adaptor::WorkspaceCollabAdaptor;
use lib_infra::async_entry::AsyncEntry;
use lib_infra::box_any::BoxAny;
use lib_infra::priority_task::TaskDispatcher;
use tokio::sync::RwLock as TokioRwLock;
use uuid::Uuid;

pub trait DatabaseUser: Send + Sync {
  fn user_id(&self) -> Result<i64, FlowyError>;
  fn collab_db(&self, uid: i64) -> Result<Weak<CollabKVDB>, FlowyError>;
  fn workspace_id(&self) -> Result<Uuid, FlowyError>;
  fn workspace_database_object_id(&self) -> Result<Uuid, FlowyError>;
  fn collab_client_id(&self, workspace_id: &Uuid) -> ClientID;
}

pub struct DatabaseManager {
  user: Arc<dyn DatabaseUser>,
  workspace_database: Arc<ArcSwapOption<RwLock<WorkspaceDatabase>>>,
  task_scheduler: Arc<TokioRwLock<TaskDispatcher>>,
  database_editors: Arc<DashMap<String, DatabaseEditorEntry>>,
  collab_service: RwLock<Option<Arc<DatabaseCollabServiceImpl>>>,
  collab_builder: Weak<WorkspaceCollabAdaptor>,
  cloud_service: Arc<dyn DatabaseCloudService>,
  ai_service: Arc<dyn DatabaseAIService>,
  removal_timeout: Duration,
}

impl Drop for DatabaseManager {
  fn drop(&mut self) {
    trace!("[Drop] drop database manager");
  }
}

impl DatabaseManager {
  pub fn new(
    database_user: Arc<dyn DatabaseUser>,
    task_scheduler: Arc<TokioRwLock<TaskDispatcher>>,
    collab_builder: Weak<WorkspaceCollabAdaptor>,
    cloud_service: Arc<dyn DatabaseCloudService>,
    ai_service: Arc<dyn DatabaseAIService>,
  ) -> Self {
    let removal_timeout = if cfg!(debug_assertions) {
      Duration::from_secs(10) // Shorter timeout for debug builds
    } else {
      Duration::from_secs(60 * 10)
    };

    let manager = Self {
      user: database_user,
      workspace_database: Default::default(),
      task_scheduler,
      database_editors: Arc::new(DashMap::new()),
      collab_service: Default::default(),
      collab_builder,
      cloud_service,
      ai_service,
      removal_timeout,
    };

    // Start periodic cleanup task
    manager.start_periodic_cleanup();
    manager
  }

  fn collab_builder(&self) -> FlowyResult<Arc<WorkspaceCollabAdaptor>> {
    self.collab_builder.upgrade().ok_or(FlowyError::ref_drop())
  }

  /// When initialize with new workspace, all the resources will be cleared.
  pub async fn initialize(&self, _uid: i64, is_local_user: bool) -> FlowyResult<()> {
    // 1. Clear all existing tasks
    self.task_scheduler.write().await.clear_task();
    // 2. Release all existing editors
    for entry in self.database_editors.iter() {
      if let Some(database) = entry.value().get_resource().await {
        database.close_all_views().await;
      }
    }
    self.database_editors.clear();
    // 3. Clear the workspace database
    if let Some(old_workspace_database) = self.workspace_database.swap(None) {
      info!("Close the old workspace database");
      let wdb = old_workspace_database.read().await;
      wdb.close();
    }

    let collab_service = Arc::new(DatabaseCollabServiceImpl::new(
      is_local_user,
      self.user.clone(),
      self.collab_builder.clone(),
      self.cloud_service.clone(),
    ));
    self
      .collab_service
      .write()
      .await
      .replace(collab_service.clone());

    let object_id = self.user.workspace_database_object_id()?;
    let object_id_str = object_id.to_string();
    let collab_type = CollabType::WorkspaceDatabase;
    let collab = collab_service
      .build_workspace_database_collab(&object_id_str, None)
      .await?;
    let workspace = WorkspaceDatabase::open(collab)?;
    let workspace_database = Arc::new(RwLock::new(workspace));
    self
      .collab_builder()?
      .cache_collab(object_id, collab_type, workspace_database.clone())
      .await?;

    self.workspace_database.store(Some(workspace_database));
    Ok(())
  }

  #[instrument(
    name = "database_initialize_after_sign_up",
    level = "debug",
    skip_all,
    err
  )]
  pub async fn initialize_after_sign_up(
    &self,
    user_id: i64,
    is_local_user: bool,
  ) -> FlowyResult<()> {
    self.initialize(user_id, is_local_user).await?;
    Ok(())
  }

  pub async fn initialize_after_open_workspace(
    &self,
    user_id: i64,
    is_local_user: bool,
  ) -> FlowyResult<()> {
    self.initialize(user_id, is_local_user).await?;
    Ok(())
  }

  pub async fn initialize_after_sign_in(
    &self,
    user_id: i64,
    is_local_user: bool,
  ) -> FlowyResult<()> {
    self.initialize(user_id, is_local_user).await?;
    Ok(())
  }

  pub async fn get_all_databases_meta(&self) -> Vec<DatabaseMeta> {
    let mut items = vec![];
    if let Some(lock) = self.workspace_database.load_full() {
      let wdb = lock.read().await;
      items = wdb.get_all_database_meta()
    }
    items
  }

  pub async fn get_database_meta(&self, database_id: &str) -> FlowyResult<Option<DatabaseMeta>> {
    let mut database_meta = None;
    if let Some(lock) = self.workspace_database.load_full() {
      let wdb = lock.read().await;
      database_meta = wdb.get_database_meta(database_id);
    }
    Ok(database_meta)
  }

  #[instrument(level = "trace", skip_all, err)]
  pub async fn update_database_indexing(
    &self,
    view_ids_by_database_id: HashMap<String, Vec<String>>,
  ) -> FlowyResult<()> {
    let lock = self.workspace_database()?;
    let mut wdb = lock.write().await;
    view_ids_by_database_id
      .into_iter()
      .for_each(|(database_id, view_ids)| {
        wdb.add_database(&database_id, view_ids);
      });
    Ok(())
  }

  pub async fn get_database_id_with_view_id(&self, view_id: &str) -> FlowyResult<String> {
    let lock = self.workspace_database()?;
    let wdb = lock.read().await;
    let database_id = wdb
      .get_database_meta_with_view_id(view_id)
      .map(|record| record.database_id);

    database_id.ok_or_else(|| {
      FlowyError::record_not_found()
        .with_context(format!("The database for view id: {} not found", view_id))
    })
  }

  pub async fn get_database_row_ids_with_view_id(&self, view_id: &str) -> FlowyResult<Vec<RowId>> {
    let database = self.get_database_editor_with_view_id(view_id).await?;
    Ok(database.get_row_ids().await)
  }

  pub async fn get_database_row_metas_with_view_id(
    &self,
    view_id: &Uuid,
    row_ids: Vec<RowId>,
  ) -> FlowyResult<Vec<RowMetaPB>> {
    let database = self
      .get_database_editor_with_view_id(view_id.to_string().as_str())
      .await?;
    let view_id = view_id.to_string();
    let mut row_metas: Vec<RowMetaPB> = vec![];
    for row_id in row_ids {
      if let Some(row_meta) = database.get_row_meta(&view_id, &row_id).await {
        row_metas.push(row_meta);
      }
    }
    Ok(row_metas)
  }

  pub async fn get_database_editor_with_view_id(
    &self,
    view_id: &str,
  ) -> FlowyResult<Arc<DatabaseEditor>> {
    let database_id = self.get_database_id_with_view_id(view_id).await?;
    self.get_or_init_database_editor(&database_id).await
  }

  pub async fn get_or_init_database_editor(
    &self,
    database_id: &str,
  ) -> FlowyResult<Arc<DatabaseEditor>> {
    // Try to get existing editor
    if let Some(editor_entry) = self.database_editors.get(database_id) {
      if let Some(database) = editor_entry.get_resource().await {
        return Ok(database);
      }
    }

    trace!("[Database]: Creating new database editor: {}", database_id);
    let editor = self.get_or_init_database(database_id).await?;
    Ok(editor)
  }

  /// Open the database view
  #[instrument(level = "trace", skip_all, err)]
  pub async fn open_database_view(&self, view_id: &Uuid) -> FlowyResult<()> {
    let view_id = view_id.to_string();
    let lock = self.workspace_database()?;
    let workspace_database = lock.read().await;
    let result = workspace_database
      .get_database_meta_with_view_id(&view_id)
      .map(|record| record.database_id);
    drop(workspace_database);

    if let Some(database_id) = result {
      let _ = self.get_or_init_database_editor(&database_id).await?;
    }
    Ok(())
  }

  #[instrument(level = "trace", skip_all, err)]
  pub async fn close_database_view(&self, view_id: &str) -> FlowyResult<()> {
    let lock = self.workspace_database()?;
    let workspace_database = lock.read().await;
    let database_id = workspace_database
      .get_database_meta_with_view_id(view_id)
      .map(|record| record.database_id);
    drop(workspace_database);

    if let Some(database_id) = database_id {
      if let Some(editor_entry) = self
        .database_editors
        .get(&database_id)
        .map(|e| e.value().clone())
      {
        if let Some(editor) = editor_entry.get_resource().await {
          editor.close_view(view_id).await;
          editor.close_database().await;
          let num_views = editor.num_of_opening_views().await;
          if num_views == 0 {
            trace!("[Database]: removing database editor: {}", database_id);
            self.database_editors.remove(&database_id);
          }
        }
      }
    }

    Ok(())
  }

  pub async fn delete_database_view(&self, view_id: &str) -> FlowyResult<()> {
    let database = self.get_database_editor_with_view_id(view_id).await?;
    let _ = database.delete_database_view(view_id).await?;
    Ok(())
  }

  pub async fn get_database_data(&self, view_id: &str) -> FlowyResult<DatabaseData> {
    let database_id = self.get_database_id_with_view_id(view_id).await?;
    let database = self.get_or_init_database_editor(&database_id).await?;
    let data = database
      .get_mutex_database()
      .read()
      .await
      .get_database_data()
      .await;
    Ok(data)
  }

  pub async fn get_database_json_string(&self, view_id: &str) -> FlowyResult<String> {
    let data = self.get_database_data(view_id).await?;
    let json_string = serde_json::to_string(&data)?;
    Ok(json_string)
  }

  /// Create a new database with the given data that can be deserialized to [DatabaseData].
  #[tracing::instrument(level = "trace", skip_all, err)]
  pub async fn create_database_with_data(
    &self,
    new_database_view_id: &str,
    data: Vec<u8>,
  ) -> FlowyResult<()> {
    let database_data = DatabaseData::from_json_bytes(data)?;
    if database_data.views.is_empty() {
      return Err(FlowyError::invalid_data().with_context("The database data is empty"));
    }

    // choose the first view as the display view. The new database_view_id is the ID in the Folder.
    let database_view_id = database_data.views[0].id.clone();
    let params = CreateDatabaseParams::from_database_data(
      database_data,
      &database_view_id,
      new_database_view_id,
    );

    self.trace_database(&params).await?;
    self.create_database(params).await?;
    Ok(())
  }

  /// When duplicating a database view, it will duplicate all the database views and replace the duplicated
  /// database_view_id with the new_database_view_id. The new database id is the ID created by Folder.
  #[tracing::instrument(level = "trace", skip_all, err)]
  pub async fn duplicate_database(
    &self,
    database_view_id: &str,
    new_database_view_id: &str,
  ) -> FlowyResult<()> {
    let database_data = self.get_database_data(database_view_id).await?;
    let params = CreateDatabaseParams::from_database_data(
      database_data,
      database_view_id,
      new_database_view_id,
    );

    self.trace_database(&params).await?;
    self.create_database(params).await?;
    Ok(())
  }

  pub async fn import_database(
    &self,
    params: CreateDatabaseParams,
  ) -> FlowyResult<Arc<RwLock<Database>>> {
    if params.rows.len() > 500 {
      return Err(
        FlowyError::invalid_data()
          .with_context("Only support importing csv with less than 500 rows"),
      );
    }
    self.trace_database(&params).await?;
    let database = self.create_database(params).await?;
    Ok(database)
  }

  async fn trace_database(&self, params: &CreateDatabaseParams) -> FlowyResult<()> {
    let mut linked_views = HashSet::new();
    linked_views.extend(params.views.iter().map(|view| view.view_id.clone()));

    let lock = self.workspace_database()?;
    let mut wdb = lock.write().await;
    wdb.add_database(&params.database_id, linked_views.into_iter().collect());
    Ok(())
  }

  /// A linked view is a view that is linked to existing database.
  #[tracing::instrument(level = "trace", skip(self), err)]
  pub async fn create_linked_view(
    &self,
    name: String,
    layout: DatabaseLayout,
    database_id: String,
    database_view_id: String,
    database_parent_view_id: String,
  ) -> FlowyResult<()> {
    info!(
      "[database] create linked view: {}, layout: {:?}, database_id: {}, database_view_id: {}",
      name, layout, database_id, database_view_id
    );

    let mut params =
      CreateViewParams::new(database_id.clone(), database_view_id.clone(), name, layout);
    if let Ok(editor) = self.get_or_init_database(&database_id).await {
      let (field, layout_setting, field_settings_map) =
        DatabaseLayoutDepsResolver::new(editor.database.clone(), layout)
          .resolve_deps_when_create_database_linked_view(&database_parent_view_id)
          .await;
      if let Some(field) = field {
        params = params.with_deps_fields(vec![field], vec![default_field_settings_by_layout_map()]);
      }
      if let Some(layout_setting) = layout_setting {
        params = params.with_layout_setting(layout_setting);
      }
      if let Some(field_settings_map) = field_settings_map {
        params = params.with_field_settings_map(field_settings_map);
      }

      editor.create_linked_view(params).await?;
    };

    let workspace_database = self.workspace_database()?;
    let mut wdb = workspace_database.write().await;
    wdb.update_database(&database_id, |record| {
      if record.linked_views.contains(&database_view_id) {
        error!("The view is already linked to the database");
      } else {
        debug!("Insert linked view record: {}", database_view_id);
        record.linked_views.push(database_view_id.clone());
      }
    });
    Ok(())
  }

  pub async fn import_csv(
    &self,
    view_id: String,
    content: String,
    format: CSVFormat,
  ) -> FlowyResult<ImportResult> {
    let params = match format {
      CSVFormat::Original => {
        let mut csv_template = CSVTemplate::try_from_reader(content.as_bytes(), true, None)?;
        csv_template.reset_view_id(view_id.clone());

        let database_template = csv_template.try_into_database_template(None).await?;
        database_template.into_params()
      },

      CSVFormat::META => {
        let cloned_view_id = view_id.clone();
        tokio::task::spawn_blocking(move || {
          CSVImporter.import_csv_from_string(cloned_view_id, content, format)
        })
        .await
        .map_err(internal_error)??
      },
    };

    let database_id = params.database_id.clone();
    let database = self.import_database(params).await?;
    let encoded_database = database.read().await.encode_database_collabs().await?;
    let encoded_collabs = std::iter::once(encoded_database.encoded_database_collab)
      .chain(encoded_database.encoded_row_collabs.into_iter())
      .collect::<Vec<_>>();

    let result = ImportResult {
      database_id,
      view_id,
      encoded_collabs,
    };
    info!("import csv result: {}", result);
    Ok(result)
  }

  pub async fn export_csv(&self, view_id: &str, style: CSVFormat) -> FlowyResult<String> {
    let database = self.get_database_editor_with_view_id(view_id).await?;
    database.export_csv(style).await
  }

  pub async fn update_database_layout(
    &self,
    view_id: &str,
    layout: DatabaseLayoutPB,
  ) -> FlowyResult<()> {
    let database = self.get_database_editor_with_view_id(view_id).await?;
    database
      .update_view_layout(view_id.to_string().as_str(), layout.into())
      .await
  }

  pub async fn get_database_snapshots(
    &self,
    view_id: &str,
    limit: usize,
  ) -> FlowyResult<Vec<DatabaseSnapshotPB>> {
    let database_id = Uuid::from_str(&self.get_database_id_with_view_id(view_id).await?)?;
    let snapshots = self
      .cloud_service
      .get_database_collab_object_snapshots(&database_id, limit)
      .await?
      .into_iter()
      .map(|snapshot| DatabaseSnapshotPB {
        snapshot_id: snapshot.snapshot_id,
        snapshot_desc: "".to_string(),
        created_at: snapshot.created_at,
        data: snapshot.data,
      })
      .collect::<Vec<_>>();

    Ok(snapshots)
  }

  #[instrument(level = "debug", skip_all)]
  pub async fn summarize_row(
    &self,
    view_id: &str,
    row_id: RowId,
    field_id: String,
  ) -> FlowyResult<()> {
    let database = self.get_database_editor_with_view_id(view_id).await?;
    let mut summary_row_content = SummaryRowContent::new();
    if let Some(row) = database.get_row(view_id, &row_id).await {
      let fields = database.get_fields(view_id, None).await;
      for field in fields {
        // When summarizing a row, skip the content in the "AI summary" cell; it does not need to
        // be summarized.
        if field.id != field_id {
          if FieldType::from(field.field_type).is_ai_field() {
            continue;
          }
          if let Some(cell) = row.cells.get(&field.id) {
            summary_row_content.insert(field.name.clone(), stringify_cell(cell, &field));
          }
        }
      }
    }

    // Call the cloud service to summarize the row.
    debug!(
      "[AI]:summarize row:{}, content:{:?}",
      row_id, summary_row_content
    );
    let response = self
      .ai_service
      .summary_database_row(
        &self.user.workspace_id()?,
        &Uuid::from_str(&row_id)?,
        summary_row_content,
      )
      .await?;
    debug!("[AI]:summarize row response: {}", response);

    // Update the cell with the response from the cloud service.
    database
      .update_cell_with_changeset(view_id, &row_id, &field_id, BoxAny::new(response))
      .await?;
    Ok(())
  }

  #[instrument(level = "debug", skip_all)]
  pub async fn translate_row(
    &self,
    view_id: &str,
    row_id: RowId,
    field_id: String,
  ) -> FlowyResult<()> {
    let database = self.get_database_editor_with_view_id(view_id).await?;
    let view_id = view_id.to_string();
    let mut translate_row_content = TranslateRowContent::new();
    let mut language = "english".to_string();

    if let Some(row) = database.get_row(&view_id, &row_id).await {
      let fields = database.get_fields(&view_id, None).await;
      for field in fields {
        // When translate a row, skip the content in the "AI Translate" cell; it does not need to
        // be translated.
        if field.id != field_id {
          if FieldType::from(field.field_type).is_ai_field() {
            continue;
          }

          if let Some(cell) = row.cells.get(&field.id) {
            translate_row_content.push(TranslateItem {
              title: field.name.clone(),
              content: stringify_cell(cell, &field),
            })
          }
        } else {
          language = TranslateTypeOption::language_from_type(
            field
              .type_options
              .get(&FieldType::Translate.to_string())
              .cloned()
              .map(TranslateTypeOption::from)
              .unwrap_or_default()
              .language_type,
          )
          .to_string();
        }
      }
    }

    // Call the cloud service to summarize the row.
    debug!(
      "[AI]:translate to {}, content:{:?}",
      language, translate_row_content
    );
    let response = self
      .ai_service
      .translate_database_row(&self.user.workspace_id()?, translate_row_content, &language)
      .await?;

    // Format the response items into a single string
    let content = response
      .items
      .into_iter()
      .map(|value| {
        value
          .into_values()
          .map(|v| v.to_string())
          .collect::<Vec<String>>()
          .join(", ")
      })
      .collect::<Vec<String>>()
      .join(",");

    debug!("[AI]:translate row response: {}", content);
    // Update the cell with the response from the cloud service.
    database
      .update_cell_with_changeset(&view_id, &row_id, &field_id, BoxAny::new(content))
      .await?;
    Ok(())
  }

  /// Start a periodic cleanup task to remove old entries from removing_editor
  fn start_periodic_cleanup(&self) {
    let weak_database_editors = Arc::downgrade(&self.database_editors);
    let cleanup_interval = Duration::from_secs(30); // Check every 30 seconds
    let base_timeout = self.removal_timeout;

    tokio::spawn(async move {
      let mut interval = tokio::time::interval(cleanup_interval);
      interval.tick().await;

      loop {
        interval.tick().await;
        if let Some(database_editors) = weak_database_editors.upgrade() {
          let mut to_remove = Vec::new();
          let timeout = base_timeout;

          // Collect entries to remove
          for entry in database_editors.iter() {
            let database_id = entry.key();
            let editor_entry = entry.value();
            if editor_entry.can_be_removed(timeout).await {
              debug!(
                "[Database]: Periodic cleanup: database {} can be removed. timeout duration: {}",
                database_id,
                timeout.as_secs()
              );
              to_remove.push(database_id.clone());
            }
          }

          // Remove expired entries and close databases
          for database_id in to_remove {
            database_editors.remove(&database_id);
          }
        } else {
          break;
        }
      }
    });
  }

  async fn get_or_init_database(
    &self,
    database_id: &str,
  ) -> Result<Arc<DatabaseEditor>, FlowyError> {
    let entry = self
      .database_editors
      .entry(database_id.to_string())
      .or_insert_with(|| DatabaseEditorEntry::new_initializing(database_id.to_string()))
      .clone();

    // Check if we already have the database after acquiring entry
    if let Some(database) = entry.get_resource().await {
      debug!("Database already initialized: {}", database_id);
      return Ok(database);
    }

    // Try to start initialization
    if entry.try_mark_initialization_start().await {
      debug!("Initializing database: {}", database_id);
      let collab_service = self.get_collab_service().await?;
      let changed_collab_rx = collab_service.subscribe_changed_collab().await?;
      let context = DatabaseContext::new(
        collab_service.clone(),
        Arc::new(DatabaseRowCollabServiceMiddleware::new(collab_service)),
      );

      match Database::arc_open(database_id, context).await {
        Ok(database) => {
          let collab_builder = self.collab_builder()?;
          let editor = DatabaseEditor::new(
            database,
            self.task_scheduler.clone(),
            collab_builder,
            changed_collab_rx,
          )
          .await?;

          // Store the database in the entry
          entry.set_resource(editor.clone()).await;
          trace!("Database opened and stored: {}", database_id);
          Ok(editor)
        },
        Err(err) => {
          error!("Open database failed: {}", err);
          entry.mark_initialization_failed(err.to_string()).await;
          Err(FlowyError::internal().with_context(err))
        },
      }
    } else {
      // Another task is initializing, wait for it to complete
      debug!("Waiting for database initialization: {}", database_id);
      match entry.wait_for_initialization(Duration::from_secs(10)).await {
        Ok(database) => {
          debug!("Database initialization completed: {}", database_id);
          Ok(database)
        },
        Err(err) => {
          error!("Database initialization failed or timed out: {}", err);
          Err(FlowyError::internal().with_context(err))
        },
      }
    }
  }

  async fn get_collab_service(&self) -> FlowyResult<Arc<DatabaseCollabServiceImpl>> {
    let collab_service = self
      .collab_service
      .read()
      .await
      .as_ref()
      .map(|v| v.clone())
      .ok_or_else(|| FlowyError::internal().with_context("Collab service not initialized"))?;
    Ok(collab_service)
  }

  async fn create_database(
    &self,
    params: CreateDatabaseParams,
  ) -> Result<Arc<RwLock<Database>>, FlowyError> {
    let entry = self
      .database_editors
      .entry(params.database_id.clone())
      .or_insert_with(|| DatabaseEditorEntry::new_initializing(params.database_id.clone()));

    let collab_service = self.get_collab_service().await?;
    let changed_collab_rx = collab_service.subscribe_changed_collab().await?;
    let context = DatabaseContext::new(
      collab_service.clone(),
      Arc::new(DatabaseRowCollabServiceMiddleware::new(collab_service)),
    );

    let database = Database::create_arc_with_view(params, context).await?;
    let editor = DatabaseEditor::new(
      database.clone(),
      self.task_scheduler.clone(),
      self.collab_builder()?,
      changed_collab_rx,
    )
    .await?;

    entry.set_resource(editor.clone()).await;
    Ok(database)
  }

  fn workspace_database(&self) -> FlowyResult<Arc<RwLock<WorkspaceDatabase>>> {
    self
      .workspace_database
      .load_full()
      .ok_or_else(|| FlowyError::internal().with_context("Workspace database not initialized"))
  }
}

type DatabaseEditorEntry = AsyncEntry<Arc<DatabaseEditor>, String>;
