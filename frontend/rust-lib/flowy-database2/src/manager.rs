use anyhow::anyhow;
use arc_swap::ArcSwapOption;
use async_trait::async_trait;
use collab::core::collab::{CollabOptions, DataSource, default_client_id};
use collab::core::origin::CollabOrigin;
use collab::lock::RwLock;
use collab::preclude::{ClientID, Collab};
use collab_database::database::{
  Database, DatabaseBody, DatabaseContext, DatabaseData, default_database_collab,
};
use collab_database::entity::{CreateDatabaseParams, CreateViewParams, EncodedDatabase};
use collab_database::error::DatabaseError;
use collab_database::fields::translate_type_option::TranslateTypeOption;
use collab_database::rows::{DatabaseRow, RowChangeSender, RowId};
use collab_database::template::csv::CSVTemplate;
use collab_database::views::DatabaseLayout;
use collab_database::workspace_database::{
  CollabPersistenceImpl, DatabaseCollabPersistenceService, DatabaseCollabService,
  DatabaseDataVariant, DatabaseMeta, DatabaseRowDataVariant, EncodeCollabByOid,
  WorkspaceDatabaseManager,
};
use collab_entity::{CollabType, EncodedCollab};
use collab_plugins::CollabKVDB;
use collab_plugins::local_storage::kv::KVTransactionDB;
use collab_plugins::local_storage::kv::doc::CollabKVAction;
use rayon::prelude::*;
use std::collections::HashMap;
use std::str::FromStr;
use std::sync::{Arc, Weak};
use std::time::{Duration, Instant};
use tokio::sync::Mutex;
use tracing::{debug, error, info, instrument, trace};

use flowy_database_pub::cloud::{
  DatabaseAIService, DatabaseCloudService, SummaryRowContent, TranslateItem, TranslateRowContent,
};
use flowy_error::{FlowyError, FlowyResult, internal_error};

use lib_infra::box_any::BoxAny;
use lib_infra::priority_task::TaskDispatcher;

use crate::entities::{DatabaseLayoutPB, DatabaseSnapshotPB, FieldType, RowMetaPB};
use crate::services::cell::stringify_cell;
use crate::services::database::DatabaseEditor;
use crate::services::database_view::DatabaseLayoutDepsResolver;
use crate::services::field_settings::default_field_settings_by_layout_map;
use crate::services::share::csv::{CSVFormat, CSVImporter, ImportResult};
use flowy_user_pub::workspace_collab::adaptor::WorkspaceCollabAdaptor;
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
  workspace_database_manager: Arc<ArcSwapOption<RwLock<WorkspaceDatabaseManager>>>,
  task_scheduler: Arc<TokioRwLock<TaskDispatcher>>,
  database_editors: Arc<Mutex<HashMap<String, DatabaseEditorEntry>>>,
  collab_builder: Weak<WorkspaceCollabAdaptor>,
  cloud_service: Arc<dyn DatabaseCloudService>,
  ai_service: Arc<dyn DatabaseAIService>,
  base_removal_timeout: Duration,
  max_removal_timeout: Duration,
}

impl Drop for DatabaseManager {
  fn drop(&mut self) {
    tracing::trace!("[Drop] drop database manager");
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
    let manager = Self {
      user: database_user,
      workspace_database_manager: Default::default(),
      task_scheduler,
      database_editors: Default::default(),
      collab_builder,
      cloud_service,
      ai_service,
      base_removal_timeout: Duration::from_secs(120), // 2 minutes
      max_removal_timeout: Duration::from_secs(300),  // 5 minutes
    };

    // Start periodic cleanup task
    manager.start_periodic_cleanup();
    manager
  }

  /// Configure removal timeouts
  pub fn configure_removal_timeouts(&mut self, base_timeout: Duration, max_timeout: Duration) {
    self.base_removal_timeout = base_timeout;
    self.max_removal_timeout = max_timeout;
  }

  fn collab_builder(&self) -> FlowyResult<Arc<WorkspaceCollabAdaptor>> {
    self.collab_builder.upgrade().ok_or(FlowyError::ref_drop())
  }

  /// When initialize with new workspace, all the resources will be cleared.
  pub async fn initialize(&self, _uid: i64, is_local_user: bool) -> FlowyResult<()> {
    // 1. Clear all existing tasks
    self.task_scheduler.write().await.clear_task();
    // 2. Release all existing editors
    for (_, editor) in self.database_editors.lock().await.iter() {
      editor.editor.close_all_views().await;
    }
    self.database_editors.lock().await.clear();
    // 3. Clear the workspace database
    if let Some(old_workspace_database) = self.workspace_database_manager.swap(None) {
      info!("Close the old workspace database");
      let wdb = old_workspace_database.read().await;
      wdb.close();
    }

    let collab_service = WorkspaceDatabaseCollabServiceImpl::new(
      is_local_user,
      self.user.clone(),
      self.collab_builder.clone(),
      self.cloud_service.clone(),
    );

    let object_id = self.user.workspace_database_object_id()?;
    let object_id_str = object_id.to_string();

    let collab_type = CollabType::WorkspaceDatabase;
    let collab = collab_service
      .build_workspace_database_collab(&object_id_str, None)
      .await?;
    let workspace = WorkspaceDatabaseManager::open(&object_id.to_string(), collab, collab_service)?;
    let workspace_database = Arc::new(RwLock::new(workspace));
    self
      .collab_builder()?
      .cache_collab_ref(object_id, collab_type, workspace_database.clone())
      .await?;

    self
      .workspace_database_manager
      .store(Some(workspace_database));
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
    if let Some(lock) = self.workspace_database_manager.load_full() {
      let wdb = lock.read().await;
      items = wdb.get_all_database_meta()
    }
    items
  }

  pub async fn get_database_meta(&self, database_id: &str) -> FlowyResult<Option<DatabaseMeta>> {
    let mut database_meta = None;
    if let Some(lock) = self.workspace_database_manager.load_full() {
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
        wdb.track_database(&database_id, view_ids);
      });
    Ok(())
  }

  pub async fn get_database_id_with_view_id(&self, view_id: &str) -> FlowyResult<String> {
    let lock = self.workspace_database()?;
    let wdb = lock.read().await;
    let database_id = wdb.get_database_id_with_view_id(view_id);
    database_id.ok_or_else(|| {
      FlowyError::record_not_found()
        .with_context(format!("The database for view id: {} not found", view_id))
    })
  }

  pub async fn encode_database(&self, view_id: &Uuid) -> FlowyResult<EncodedDatabase> {
    let editor = self
      .get_database_editor_with_view_id(view_id.to_string().as_str())
      .await?;
    let collabs = editor
      .database
      .read()
      .await
      .encode_database_collabs()
      .await?;
    Ok(collabs)
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
    // Check if we have an active editor
    if let Some(editor_entry) = self.database_editors.lock().await.get(database_id).cloned() {
      if editor_entry.is_active() {
        return Ok(editor_entry.editor);
      }
    }
    let editor = self.open_database(database_id).await?;
    Ok(editor)
  }

  #[instrument(level = "trace", skip_all, err)]
  pub async fn open_database(&self, database_id: &str) -> FlowyResult<Arc<DatabaseEditor>> {
    let workspace_database = self.workspace_database()?;
    // Check if we have an existing editor (active or pending removal)
    {
      let mut editors = self.database_editors.lock().await;
      if let Some(editor_entry) = editors.remove(database_id) {
        let reactivated_entry = editor_entry.reactivate();
        let editor = reactivated_entry.editor.clone();

        trace!(
          "[Database]: Reactivated database editor: {}, access_count: {}",
          database_id,
          reactivated_entry.access_count()
        );

        editors.insert(database_id.to_string(), reactivated_entry);
        return Ok(editor);
      }
    }

    trace!("[Database]: Creating new database editor: {}", database_id);
    // When the user opens the database from the left-side bar, it may fail because the workspace database
    // hasn't finished syncing yet. In such cases, get_or_create_database will return None.
    // The workaround is to add a retry mechanism to attempt fetching the database again.
    let database = open_database_with_retry(workspace_database, database_id).await?;
    let collab_builder = self.collab_builder()?;
    let editor = DatabaseEditor::new(
      self.user.clone(),
      database,
      self.task_scheduler.clone(),
      collab_builder,
    )
    .await?;

    self.database_editors.lock().await.insert(
      database_id.to_string(),
      DatabaseEditorEntry::new_active(editor.clone()),
    );
    Ok(editor)
  }

  /// Open the database view
  #[instrument(level = "trace", skip_all, err)]
  pub async fn open_database_view(&self, view_id: &Uuid) -> FlowyResult<()> {
    let view_id = view_id.to_string();
    let lock = self.workspace_database()?;
    let workspace_database = lock.read().await;
    let result = workspace_database.get_database_id_with_view_id(&view_id);
    drop(workspace_database);

    if let Some(database_id) = result {
      let has_active_editor = self
        .database_editors
        .lock()
        .await
        .get(&database_id)
        .map(|entry| entry.is_active())
        .unwrap_or(false);

      if !has_active_editor {
        let _ = self.open_database(&database_id).await?;
      }
    }
    Ok(())
  }

  #[instrument(level = "trace", skip_all, err)]
  pub async fn close_database_view(&self, view_id: &str) -> FlowyResult<()> {
    let lock = self.workspace_database()?;
    let workspace_database = lock.read().await;
    let database_id = workspace_database.get_database_id_with_view_id(view_id);
    drop(workspace_database);

    if let Some(database_id) = database_id {
      let mut editors = self.database_editors.lock().await;
      if let Some(editor_entry) = editors.get(&database_id) {
        if editor_entry.is_active() {
          editor_entry.editor.close_view(view_id).await;
          // when there is no opening views, mark the database for removal
          let num_views = editor_entry.editor.num_of_opening_views().await;
          trace!(
            "[Database]: {} has {} opening views",
            database_id, num_views
          );

          if num_views == 0 {
            // Simply mark for removal and let periodic cleanup handle it
            if let Some(editor_entry) = editors.remove(&database_id) {
              editor_entry.editor.close_database().await;
              let pending_entry = editor_entry.mark_for_removal();
              editors.insert(database_id.to_string(), pending_entry);
              trace!("[Database]: Marked {} for removal", database_id);
            }
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
    let lock = self.workspace_database()?;
    let wdb = lock.read().await;
    let data = wdb.get_database_data(view_id).await?;
    Ok(data)
  }

  pub async fn get_database_json_string(&self, view_id: &str) -> FlowyResult<String> {
    let lock = self.workspace_database()?;
    let wdb = lock.read().await;
    let data = wdb.get_database_data(view_id).await?;
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
    let create_database_params = CreateDatabaseParams::from_database_data(
      database_data,
      &database_view_id,
      new_database_view_id,
    );

    let lock = self.workspace_database()?;
    let mut wdb = lock.write().await;
    let _ = wdb.create_database(create_database_params).await?;
    drop(wdb);

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
    let lock = self.workspace_database()?;
    let mut wdb = lock.write().await;
    let _ = wdb
      .duplicate_database(database_view_id, new_database_view_id)
      .await?;
    drop(wdb);
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

    let lock = self.workspace_database()?;
    let mut wdb = lock.write().await;
    let database = wdb.create_database(params).await?;
    drop(wdb);

    Ok(database)
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
    let workspace_database = self.workspace_database()?;
    let mut wdb = workspace_database.write().await;
    let mut params = CreateViewParams::new(database_id.clone(), database_view_id, name, layout);
    if let Ok(database) = wdb.get_or_init_database(&database_id).await {
      let (field, layout_setting, field_settings_map) =
        DatabaseLayoutDepsResolver::new(database, layout)
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
    };
    wdb.create_database_linked_view(params).await?;
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

  fn workspace_database(&self) -> FlowyResult<Arc<RwLock<WorkspaceDatabaseManager>>> {
    self
      .workspace_database_manager
      .load_full()
      .ok_or_else(|| FlowyError::internal().with_context("Workspace database not initialized"))
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
    trace!(
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
    trace!("[AI]:summarize row response: {}", response);

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
    trace!(
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

    trace!("[AI]:translate row response: {}", content);
    // Update the cell with the response from the cloud service.
    database
      .update_cell_with_changeset(&view_id, &row_id, &field_id, BoxAny::new(content))
      .await?;
    Ok(())
  }

  /// Only expose this method for testing
  #[cfg(debug_assertions)]
  pub fn get_cloud_service(&self) -> &Arc<dyn DatabaseCloudService> {
    &self.cloud_service
  }

  /// Start a periodic cleanup task to remove old entries from removing_editor
  fn start_periodic_cleanup(&self) {
    let weak_database_editors = Arc::downgrade(&self.database_editors);
    let weak_workspace_database = Arc::downgrade(&self.workspace_database_manager);
    let cleanup_interval = Duration::from_secs(30); // Check every 30 seconds
    let base_timeout = self.base_removal_timeout;
    let max_timeout = self.max_removal_timeout;

    tokio::spawn(async move {
      let mut interval = tokio::time::interval(cleanup_interval);
      loop {
        interval.tick().await;

        if let Some(database_editors) = weak_database_editors.upgrade() {
          let mut editors = database_editors.lock().await;
          let now = Instant::now();
          let mut to_remove = Vec::new();
          for (database_id, entry) in editors.iter() {
            if let Some(removal_time) = entry.removal_time() {
              // Calculate dynamic timeout based on access patterns
              let access_multiplier = (entry.access_count() as f64 / 10.0).min(2.0);
              let timeout = Duration::from_secs(
                (base_timeout.as_secs() as f64 * (1.0 + access_multiplier)) as u64,
              )
              .min(max_timeout);

              if now.duration_since(removal_time) >= timeout {
                to_remove.push(database_id.clone());
              }
            }
          }

          // Remove expired entries and close databases
          for database_id in to_remove {
            if let Some(entry) = editors.remove(&database_id) {
              if entry.is_pending_removal() {
                trace!(
                  "[Database]: Periodic cleanup removing database: {}",
                  database_id
                );

                // Close the database in the workspace
                if let Some(workspace_manager) = weak_workspace_database.upgrade() {
                  if let Some(workspace) = workspace_manager.load_full() {
                    let wdb = workspace.write().await;
                    wdb.close_database(&database_id);
                  }
                }
              } else {
                editors.insert(database_id, entry);
              }
            }
          }

          // Also remove entries that have been pending for too long (safety cleanup)
          let max_age = Duration::from_secs(600); // 10 minutes absolute max
          let initial_count = editors.len();
          editors.retain(|database_id, entry| {
            if let Some(removal_time) = entry.removal_time() {
              let should_retain = now.duration_since(removal_time) < max_age;
              if !should_retain {
                trace!(
                  "[Database]: Safety cleanup removing old entry: {}",
                  database_id
                );
              }
              should_retain
            } else {
              // Keep active entries
              true
            }
          });

          let removed_count = initial_count - editors.len();
          if removed_count > 0 {
            trace!(
              "[Database]: Periodic cleanup removed {} entries",
              removed_count
            );
          }
        } else {
          break;
        }
      }
    });
  }

  /// Get statistics about the removing_editor cache
  pub async fn get_removing_editor_stats(&self) -> (usize, Vec<(String, u32, Duration)>) {
    let database_editors = self.database_editors.lock().await;
    let now = Instant::now();

    let pending_removal_entries: Vec<_> = database_editors
      .iter()
      .filter_map(|(id, entry)| {
        if let Some(removal_time) = entry.removal_time() {
          let age = now.duration_since(removal_time);
          Some((id.clone(), entry.access_count(), age))
        } else {
          None
        }
      })
      .collect();

    let count = pending_removal_entries.len();
    (count, pending_removal_entries)
  }

  /// Force cleanup of removing_editor entries (useful for testing or manual cleanup)
  pub async fn force_cleanup_removing_editors(&self) {
    let mut database_editors = self.database_editors.lock().await;
    let initial_count = database_editors.len();

    // Only remove entries that are pending removal
    database_editors.retain(|_, entry| entry.is_active());

    let removed_count = initial_count - database_editors.len();
    trace!(
      "[Database]: Force cleaned {} pending removal entries",
      removed_count
    );
  }

  /// Get the current active editors count
  pub async fn get_active_editors_count(&self) -> usize {
    self
      .database_editors
      .lock()
      .await
      .values()
      .filter(|entry| entry.is_active())
      .count()
  }

  /// Get the current pending removal editors count
  pub async fn get_pending_removal_editors_count(&self) -> usize {
    self
      .database_editors
      .lock()
      .await
      .values()
      .filter(|entry| entry.is_pending_removal())
      .count()
  }

  /// Get total editors count (active + pending removal)
  pub async fn get_total_editors_count(&self) -> usize {
    self.database_editors.lock().await.len()
  }
}

struct WorkspaceDatabaseCollabServiceImpl {
  is_local_user: bool,
  user: Arc<dyn DatabaseUser>,
  collab_builder: Weak<WorkspaceCollabAdaptor>,
  persistence: Arc<dyn DatabaseCollabPersistenceService>,
  cloud_service: Arc<dyn DatabaseCloudService>,
}

impl WorkspaceDatabaseCollabServiceImpl {
  fn new(
    is_local_user: bool,
    user: Arc<dyn DatabaseUser>,
    collab_builder: Weak<WorkspaceCollabAdaptor>,
    cloud_service: Arc<dyn DatabaseCloudService>,
  ) -> Self {
    let persistence = DatabasePersistenceImpl { user: user.clone() };
    Self {
      is_local_user,
      user,
      collab_builder,
      persistence: Arc::new(persistence),
      cloud_service,
    }
  }

  fn collab_builder(&self) -> Result<Arc<WorkspaceCollabAdaptor>, DatabaseError> {
    self
      .collab_builder
      .upgrade()
      .ok_or_else(|| DatabaseError::Internal(anyhow!("Collab builder is not initialized")))
  }

  async fn get_encode_collab(
    &self,
    object_id: &Uuid,
    object_ty: CollabType,
  ) -> Result<Option<EncodedCollab>, DatabaseError> {
    let workspace_id = self
      .user
      .workspace_id()
      .map_err(|e| DatabaseError::Internal(e.into()))?;
    trace!("[Database]: fetch {}:{} from remote", object_id, object_ty);
    let encode_collab = self
      .cloud_service
      .get_database_encode_collab(object_id, object_ty, &workspace_id)
      .await
      .map_err(|err| DatabaseError::Internal(err.into()))?;
    Ok(encode_collab)
  }

  async fn batch_get_encode_collab(
    &self,
    object_ids: Vec<Uuid>,
    object_ty: CollabType,
  ) -> Result<EncodeCollabByOid, DatabaseError> {
    let workspace_id = self
      .user
      .workspace_id()
      .map_err(|err| DatabaseError::Internal(err.into()))?;
    let updates = self
      .cloud_service
      .batch_get_database_encode_collab(object_ids, object_ty, &workspace_id)
      .await
      .map_err(|err| DatabaseError::Internal(err.into()))?;

    Ok(
      updates
        .into_iter()
        .map(|(k, v)| (k.to_string(), v))
        .collect(),
    )
  }

  async fn get_data_source(
    &self,
    object_id: &str,
    collab_type: CollabType,
    encoded_collab: Option<EncodedCollab>,
  ) -> Result<DataSource, DatabaseError> {
    if encoded_collab.is_none()
      && self
        .persistence
        .is_collab_exist(object_id.to_string().as_str())
    {
      return Ok(
        CollabPersistenceImpl {
          persistence: Some(self.persistence.clone()),
        }
        .into(),
      );
    }

    let object_id = Uuid::parse_str(object_id)?;
    match encoded_collab {
      None => {
        info!(
          "build collab: fetch {}:{} from remote, is_new:{}",
          collab_type,
          object_id,
          encoded_collab.is_none(),
        );
        match self.get_encode_collab(&object_id, collab_type).await {
          Ok(Some(encode_collab)) => {
            info!(
              "build collab: {}:{} with remote encode collab, {} bytes",
              collab_type,
              object_id,
              encode_collab.doc_state.len()
            );
            Ok(DataSource::from(encode_collab))
          },
          Ok(None) => {
            if self.is_local_user {
              info!(
                "build collab: {}:{} with empty encode collab",
                collab_type, object_id
              );
              Ok(
                CollabPersistenceImpl {
                  persistence: Some(self.persistence.clone()),
                }
                .into(),
              )
            } else {
              Err(DatabaseError::RecordNotFound)
            }
          },
          Err(err) => {
            if !matches!(err, DatabaseError::ActionCancelled) {
              error!("build collab: failed to get encode collab: {}", err);
            }
            Err(err)
          },
        }
      },
      Some(encoded_collab) => {
        info!(
          "build collab: {}:{} with new encode collab, {} bytes",
          collab_type,
          object_id,
          encoded_collab.doc_state.len()
        );

        // TODO(nathan): cover database rows and other database collab type
        if matches!(collab_type, CollabType::Database) {
          if let Ok(workspace_id) = self.user.workspace_id() {
            let cloned_encoded_collab = encoded_collab.clone();
            let cloud_service = self.cloud_service.clone();
            tokio::spawn(async move {
              let _ = cloud_service
                .create_database_encode_collab(
                  &object_id,
                  collab_type,
                  &workspace_id,
                  cloned_encoded_collab,
                )
                .await;
            });
          }
        }
        Ok(encoded_collab.into())
      },
    }
  }

  async fn build_collab<T: Into<DataSourceOrCollab>>(
    &self,
    object_id: &str,
    collab_type: CollabType,
    data: T,
  ) -> Result<Collab, DatabaseError> {
    let data: DataSourceOrCollab = data.into();
    let workspace_id = self
      .user
      .workspace_id()
      .map_err(|err| DatabaseError::Internal(err.into()))?;

    let object_uuid = Uuid::parse_str(object_id)?;
    let collab_builder = self.collab_builder()?;

    let mut collab = match data {
      DataSourceOrCollab::Collab(collab) => collab,
      DataSourceOrCollab::DataSource(source) => {
        collab_builder
          .build_collab_with_source(object_uuid, collab_type, source)
          .await?
      },
    };

    collab_builder
      .finalize_collab(workspace_id, object_uuid, collab_type, &mut collab)
      .await?;

    Ok(collab)
  }
}

enum DataSourceOrCollab {
  Collab(Collab),
  DataSource(DataSource),
}

impl From<DataSource> for DataSourceOrCollab {
  fn from(source: DataSource) -> Self {
    DataSourceOrCollab::DataSource(source)
  }
}

impl From<Collab> for DataSourceOrCollab {
  fn from(collab: Collab) -> Self {
    DataSourceOrCollab::Collab(collab)
  }
}

impl From<EncodedCollab> for DataSourceOrCollab {
  fn from(encoded_collab: EncodedCollab) -> Self {
    DataSourceOrCollab::DataSource(DataSource::from(encoded_collab))
  }
}

#[async_trait]
impl DatabaseCollabService for WorkspaceDatabaseCollabServiceImpl {
  async fn client_id(&self) -> ClientID {
    match self.collab_builder.upgrade() {
      None => default_client_id(),
      Some(b) => b.client_id().await.unwrap_or(default_client_id()),
    }
  }

  async fn build_arc_database(
    &self,
    object_id: &str,
    _is_new: bool,
    data: Option<DatabaseDataVariant>,
    context: DatabaseContext,
  ) -> Result<Arc<RwLock<Database>>, DatabaseError> {
    let database = self.build_database(object_id, false, data, context).await?;
    let database = Arc::new(RwLock::new(database));
    let object_id = Uuid::parse_str(object_id)?;
    self
      .collab_builder()?
      .cache_collab_ref(object_id, CollabType::Database, database.clone())
      .await?;
    Ok(database)
  }

  async fn build_database(
    &self,
    object_id: &str,
    _is_new: bool,
    data: Option<DatabaseDataVariant>,
    context: DatabaseContext,
  ) -> Result<Database, DatabaseError> {
    let client_id = self.client_id().await;
    let collab_type = CollabType::Database;

    let collab = match data {
      None => {
        let source = self.get_data_source(object_id, collab_type, None).await?;
        self
          .build_collab(object_id, CollabType::Database, source)
          .await?
      },
      Some(data) => match data {
        DatabaseDataVariant::Params(params) => {
          let database_id = params.database_id.clone();
          let collab =
            default_database_collab(&database_id, client_id, Some(params), context.clone())
              .await?
              .1;
          self
            .build_collab(object_id, CollabType::Database, collab)
            .await?
        },
        DatabaseDataVariant::EncodedCollab(data) => {
          self
            .build_collab(object_id, CollabType::Database, data)
            .await?
        },
      },
    };

    let collab_service = context.collab_service.clone();
    let (body, collab) = DatabaseBody::open(collab, context)?;
    Ok(Database {
      collab,
      body,
      collab_service,
    })
  }

  #[instrument(level = "info", skip_all, error)]
  async fn build_arc_database_row(
    &self,
    object_id: &str,
    _is_new: bool,
    data: Option<DatabaseRowDataVariant>,
    sender: Option<RowChangeSender>,
    collab_service: Arc<dyn DatabaseCollabService>,
  ) -> Result<Arc<RwLock<DatabaseRow>>, DatabaseError> {
    let client_id = self.client_id().await;
    let collab_type = CollabType::DatabaseRow;
    let data = data.map(|v| v.into_encode_collab(client_id));

    debug!(
      "[Database]: build arc database row: {}, collab_type: {:?}, data: {:#?}",
      object_id, collab_type, data
    );

    let source = self.get_data_source(object_id, collab_type, data).await?;
    let collab = self.build_collab(object_id, collab_type, source).await?;
    let database_row = DatabaseRow::open(RowId::from(object_id), collab, sender, collab_service)?;
    let database_row = Arc::new(RwLock::new(database_row));
    let object_id = Uuid::parse_str(object_id)?;
    self
      .collab_builder()?
      .cache_collab_ref(object_id, collab_type, database_row.clone())
      .await?;
    Ok(database_row)
  }

  async fn build_workspace_database_collab(
    &self,
    object_id: &str,
    encoded_collab: Option<EncodedCollab>,
  ) -> Result<Collab, DatabaseError> {
    let collab_type = CollabType::WorkspaceDatabase;
    let data_source = self
      .get_data_source(object_id, collab_type, encoded_collab)
      .await?;
    self.build_collab(object_id, collab_type, data_source).await
  }

  async fn get_collabs(
    &self,
    mut object_ids: Vec<String>,
    collab_type: CollabType,
  ) -> Result<EncodeCollabByOid, DatabaseError> {
    if object_ids.is_empty() {
      return Ok(EncodeCollabByOid::new());
    }

    let mut encoded_collab_by_id = EncodeCollabByOid::new();
    // 1. Collect local disk collabs into a HashMap
    let local_disk_encoded_collab: HashMap<String, EncodedCollab> = object_ids
      .par_iter()
      .filter_map(|object_id| {
        self
          .persistence
          .get_encoded_collab(object_id.as_str(), collab_type)
          .map(|encoded_collab| (object_id.clone(), encoded_collab))
      })
      .collect();
    trace!(
      "[Database]: load {} database row from local disk",
      local_disk_encoded_collab.len()
    );

    object_ids.retain(|object_id| !local_disk_encoded_collab.contains_key(object_id));
    for (k, v) in local_disk_encoded_collab {
      encoded_collab_by_id.insert(k, v);
    }

    if !object_ids.is_empty() {
      let object_ids = object_ids
        .into_iter()
        .flat_map(|v| Uuid::from_str(&v).ok())
        .collect::<Vec<_>>();
      // 2. Fetch remaining collabs from remote
      let remote_collabs = self
        .batch_get_encode_collab(object_ids, collab_type)
        .await?;

      trace!(
        "[Database]: load {} database row from remote",
        remote_collabs.len()
      );
      for (k, v) in remote_collabs {
        encoded_collab_by_id.insert(k, v);
      }
    }

    Ok(encoded_collab_by_id)
  }

  fn persistence(&self) -> Option<Arc<dyn DatabaseCollabPersistenceService>> {
    Some(self.persistence.clone())
  }
}

pub struct DatabasePersistenceImpl {
  user: Arc<dyn DatabaseUser>,
}

impl DatabasePersistenceImpl {
  fn workspace_id(&self) -> Result<Uuid, DatabaseError> {
    let workspace_id = self
      .user
      .workspace_id()
      .map_err(|err| DatabaseError::Internal(err.into()))?;
    Ok(workspace_id)
  }
}

impl DatabaseCollabPersistenceService for DatabasePersistenceImpl {
  fn load_collab(&self, collab: &mut Collab) {
    let result = self
      .user
      .user_id()
      .map(|uid| (uid, self.user.collab_db(uid).map(|weak| weak.upgrade())));

    if let Ok(workspace_id) = self.user.workspace_id() {
      if let Ok((uid, Ok(Some(collab_db)))) = result {
        let object_id = collab.object_id().to_string();
        let db_read = collab_db.read_txn();
        if !db_read.is_exist(uid, workspace_id.to_string().as_str(), &object_id) {
          trace!(
            "[Database]: collab:{} not exist in local storage",
            object_id
          );
          return;
        }

        trace!("[Database]: start loading collab:{} from disk", object_id);
        let mut txn = collab.transact_mut();
        match db_read.load_doc_with_txn(
          uid,
          workspace_id.to_string().as_str(),
          &object_id,
          &mut txn,
        ) {
          Ok(update_count) => {
            trace!(
              "[Database]: did load collab:{}, update_count:{}",
              object_id, update_count
            );
          },
          Err(err) => {
            if !err.is_record_not_found() {
              error!("[Database]: load collab:{} failed:{}", object_id, err);
            }
          },
        }
      }
    }
  }

  fn get_encoded_collab(&self, object_id: &str, collab_type: CollabType) -> Option<EncodedCollab> {
    let workspace_id = self.user.workspace_id().ok()?;
    let uid = self.user.user_id().ok()?;
    let db = self.user.collab_db(uid).ok()?.upgrade()?;
    let read_txn = db.read_txn();
    if !read_txn.is_exist(uid, workspace_id.to_string().as_str(), object_id) {
      return None;
    }

    let client_id = self.user.collab_client_id(&workspace_id);
    let options = CollabOptions::new(object_id.to_string(), client_id);
    let mut collab = Collab::new_with_options(CollabOrigin::Empty, options).ok()?;
    let mut txn = collab.transact_mut();
    let _ = read_txn.load_doc_with_txn(uid, workspace_id.to_string().as_str(), object_id, &mut txn);
    drop(txn);

    collab
      .encode_collab_v1(|collab| collab_type.validate_require_data(collab))
      .ok()
  }

  fn delete_collab(&self, object_id: &str) -> Result<(), DatabaseError> {
    let workspace_id = self.workspace_id()?.to_string();
    let uid = self
      .user
      .user_id()
      .map_err(|err| DatabaseError::Internal(err.into()))?;
    if let Ok(Some(collab_db)) = self.user.collab_db(uid).map(|weak| weak.upgrade()) {
      let write_txn = collab_db.write_txn();
      write_txn
        .delete_doc(uid, workspace_id.as_str(), object_id)
        .unwrap();
      write_txn
        .commit_transaction()
        .map_err(|err| DatabaseError::Internal(anyhow!("failed to commit transaction: {}", err)))?;
    }
    Ok(())
  }

  fn is_collab_exist(&self, object_id: &str) -> bool {
    match self.user.workspace_id() {
      Ok(workspace_id) => {
        match self
          .user
          .user_id()
          .map_err(|err| DatabaseError::Internal(err.into()))
        {
          Ok(uid) => {
            if let Ok(Some(collab_db)) = self.user.collab_db(uid).map(|weak| weak.upgrade()) {
              let read_txn = collab_db.read_txn();
              return read_txn.is_exist(uid, workspace_id.to_string().as_str(), object_id);
            }
            false
          },
          Err(_) => false,
        }
      },
      Err(_) => false,
    }
  }
}
async fn open_database_with_retry(
  workspace_database_manager: Arc<RwLock<WorkspaceDatabaseManager>>,
  database_id: &str,
) -> Result<Arc<RwLock<Database>>, DatabaseError> {
  let max_retries = 3;
  let retry_interval = Duration::from_secs(4);
  for attempt in 1..=max_retries {
    trace!(
      "[Database]: attempt {} to open database:{}",
      attempt, database_id
    );

    let result = workspace_database_manager
      .try_read()
      .map_err(|err| DatabaseError::Internal(anyhow!("workspace database lock fail: {}", err)))?
      .get_or_init_database(database_id)
      .await;

    // Attempt to open the database
    match result {
      Ok(database) => return Ok(database),
      Err(err) => {
        if matches!(err, DatabaseError::RecordNotFound)
          || matches!(err, DatabaseError::NoRequiredData(_))
        {
          error!(
            "[Database]: retry {} to open database:{}, error:{}",
            attempt, database_id, err
          );

          if attempt < max_retries {
            tokio::time::sleep(retry_interval).await;
          } else {
            error!(
              "[Database]: exhausted retries to open database:{}, error:{}",
              database_id, err
            );
            return Err(err);
          }
        } else {
          error!(
            "[Database]: stop retrying to open database:{}, error:{}",
            database_id, err
          );
          return Err(err);
        }
      },
    }
  }

  Err(DatabaseError::Internal(anyhow!(
    "Exhausted retries to open database: {}",
    database_id
  )))
}

#[derive(Clone, Debug)]
enum DatabaseEditorState {
  Active {
    access_count: u32,
  },
  PendingRemoval {
    removal_time: Instant,
    access_count: u32,
    last_access: Instant,
  },
}

#[derive(Clone)]
struct DatabaseEditorEntry {
  editor: Arc<DatabaseEditor>,
  state: DatabaseEditorState,
}

impl DatabaseEditorEntry {
  fn new_active(editor: Arc<DatabaseEditor>) -> Self {
    Self {
      editor,
      state: DatabaseEditorState::Active { access_count: 1 },
    }
  }

  fn mark_for_removal(mut self) -> Self {
    match self.state {
      DatabaseEditorState::Active { access_count, .. } => {
        self.state = DatabaseEditorState::PendingRemoval {
          removal_time: Instant::now(),
          access_count,
          last_access: Instant::now(),
        };
      },
      DatabaseEditorState::PendingRemoval { .. } => {
        // Already pending removal, update removal time
        if let DatabaseEditorState::PendingRemoval {
          access_count,
          last_access,
          ..
        } = self.state
        {
          self.state = DatabaseEditorState::PendingRemoval {
            removal_time: Instant::now(),
            access_count,
            last_access,
          };
        }
      },
    }
    self
  }

  fn reactivate(mut self) -> Self {
    match self.state {
      DatabaseEditorState::Active {
        mut access_count, ..
      } => {
        access_count += 1;
        self.state = DatabaseEditorState::Active { access_count };
      },
      DatabaseEditorState::PendingRemoval {
        mut access_count, ..
      } => {
        access_count += 1;
        self.state = DatabaseEditorState::Active { access_count };
      },
    }
    self
  }

  fn is_active(&self) -> bool {
    matches!(self.state, DatabaseEditorState::Active { .. })
  }

  fn is_pending_removal(&self) -> bool {
    matches!(self.state, DatabaseEditorState::PendingRemoval { .. })
  }

  fn access_count(&self) -> u32 {
    match self.state {
      DatabaseEditorState::Active { access_count, .. } => access_count,
      DatabaseEditorState::PendingRemoval { access_count, .. } => access_count,
    }
  }

  fn removal_time(&self) -> Option<Instant> {
    match self.state {
      DatabaseEditorState::Active { .. } => None,
      DatabaseEditorState::PendingRemoval { removal_time, .. } => Some(removal_time),
    }
  }
}
