use super::zip;
use crate::entities::ExportRequest;
use crate::manager::FolderManager;
use crate::util::folder_not_init_error;
use crate::view_operation::GatherEncodedCollab;
use collab::core::collab::default_client_id;
use collab::core::collab::{CollabOptions, DataSource};
use collab::core::origin::CollabOrigin;
use collab::lock::RwLock;
use collab::preclude::Collab;
use collab_database::database::{Database, DatabaseBody};
use collab_database::database_trait::NoPersistenceDatabaseCollabService;
use collab_database::rows::{
  DatabaseRow, DatabaseRowBody, RowId, database_row_document_id_from_row_id,
};
use collab_document::document::Document;
use collab_entity::{CollabType, EncodedCollab};
use collab_folder::{View, ViewLayout};
use collab_importer::util::FileId;
use collab_importer::workspace::entities::{
  CollabMetadata, DependencyType, ViewDependency, ViewMetadata, WorkspaceDatabaseMeta,
  WorkspaceRelationMap,
};
use dashmap::DashMap;
use flowy_error::{FlowyError, FlowyResult};
use regex::Regex;
use std::collections::{HashMap, HashSet};
use std::fs;
use std::path::PathBuf;
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};
use tracing::{error, info, instrument};
use uuid::Uuid;

type CollabDataExtractResult = (HashMap<String, Vec<u8>>, HashMap<String, String>);
pub struct WorkspaceExporter<'a> {
  folder_manager: &'a FolderManager,
}

impl<'a> WorkspaceExporter<'a> {
  pub fn new(folder_manager: &'a FolderManager) -> Self {
    Self { folder_manager }
  }

  #[instrument(level = "debug", skip(self), err)]
  pub async fn export_workspace(&self, request: ExportRequest) -> FlowyResult<()> {
    let workspace_id = self.folder_manager.user.workspace_id()?;

    if request.workspace_id != workspace_id {
      return Err(
        FlowyError::invalid_data()
          .with_context("Requested workspace ID does not match current workspace"),
      );
    }

    let views = self.discover_views(&workspace_id).await?;

    info!(
      "Starting workspace export for workspace {} with {} views to path: {}",
      workspace_id,
      views.len(),
      request.output_path
    );

    let mut relation_map = self.build_relation_map(&workspace_id, &views).await?;

    info!(
      "Built relation map with {} views and {} dependencies",
      relation_map.views.len(),
      relation_map.dependencies.len()
    );

    let (collab_data, mut doc_state_to_json) = self.extract_collab_data(&mut relation_map).await?;

    let mut seen_database_ids = HashSet::new();
    if let Some(ref mut database_meta) = relation_map.workspace_database_meta {
      database_meta.retain(|meta| seen_database_ids.insert(meta.database_id.clone()));
    }

    info!("Extracted {} collab files for export", collab_data.len());

    let local_files = self
      .collect_all_local_files(&mut doc_state_to_json, &mut relation_map)
      .await?;

    info!("Extracted {} local files for export", local_files.len());

    zip::create_export_archive(
      &request.output_path,
      &relation_map,
      &collab_data,
      &doc_state_to_json,
      &local_files,
    )?;

    info!(
      "Successfully completed workspace export for workspace {} to path: {}",
      workspace_id, request.output_path
    );

    Ok(())
  }

  #[instrument(level = "debug", skip(self), err)]
  async fn discover_views(&self, workspace_id: &Uuid) -> FlowyResult<Vec<Arc<View>>> {
    let uid = self.folder_manager.user.user_id()?;
    let lock = self
      .folder_manager
      .mutex_folder
      .load_full()
      .ok_or_else(folder_not_init_error)?;
    let folder = lock.read().await;

    let mut view_ids_should_be_filtered: HashSet<String> =
      FolderManager::get_view_ids_should_be_filtered(&folder, uid)
        .into_iter()
        .collect();
    // no need to include the workspace view itself
    view_ids_should_be_filtered.insert(workspace_id.to_string());

    let mut all_views = Vec::new();
    let mut visited = HashSet::new();

    let mut root_views = folder.get_views_belong_to(&workspace_id.to_string(), uid);
    let orphaned_views = folder
      .get_all_views(uid)
      .into_iter()
      .filter(|v| v.parent_view_id == v.id)
      .collect::<Vec<_>>();
    root_views.extend(orphaned_views);
    for view in root_views {
      if !view_ids_should_be_filtered.contains(&view.id) && view.layout != ViewLayout::Chat {
        self.collect_view_hierarchy(
          &folder,
          &view,
          &mut all_views,
          &mut visited,
          &view_ids_should_be_filtered,
          uid,
        );
      }
    }

    drop(folder);
    drop(lock);

    info!(
      "Discovered {} views for export from workspace {}",
      all_views.len(),
      workspace_id
    );

    Ok(all_views)
  }

  #[allow(clippy::only_used_in_recursion)]
  fn collect_view_hierarchy(
    &self,
    folder: &collab_folder::Folder,
    view: &Arc<View>,
    all_views: &mut Vec<Arc<View>>,
    visited: &mut HashSet<String>,
    view_ids_should_be_filtered: &HashSet<String>,
    uid: i64,
  ) {
    if visited.contains(&view.id) {
      return;
    }
    visited.insert(view.id.clone());

    all_views.push(view.clone());

    let child_views = folder.get_views_belong_to(&view.id, uid);
    for child_view in child_views {
      if !view_ids_should_be_filtered.contains(&child_view.id)
        && child_view.layout != ViewLayout::Chat
      {
        self.collect_view_hierarchy(
          folder,
          &child_view,
          all_views,
          visited,
          view_ids_should_be_filtered,
          uid,
        );
      }
    }
  }

  #[instrument(level = "debug", skip(self), err)]
  pub async fn get_views_by_ids(&self, view_ids: &[String]) -> FlowyResult<Vec<Arc<View>>> {
    let uid = self.folder_manager.user.user_id()?;
    let lock = self
      .folder_manager
      .mutex_folder
      .load_full()
      .ok_or_else(folder_not_init_error)?;
    let folder = lock.read().await;

    let mut views = Vec::new();
    let mut missing_view_ids = Vec::new();

    for view_id in view_ids {
      if let Some(view) = folder.get_view(view_id, uid) {
        views.push(view);
      } else {
        missing_view_ids.push(view_id.clone());
      }
    }

    drop(folder);
    drop(lock);

    if !missing_view_ids.is_empty() {
      info!(
        "Some views were not found: {:?}. Found {} out of {} requested views.",
        missing_view_ids,
        views.len(),
        view_ids.len()
      );
    }

    info!("Retrieved {} views by IDs", views.len());
    Ok(views)
  }

  #[instrument(level = "debug", skip(self, views), err)]
  pub async fn build_relation_map(
    &self,
    workspace_id: &Uuid,
    views: &[Arc<View>],
  ) -> FlowyResult<WorkspaceRelationMap> {
    let export_timestamp = SystemTime::now()
      .duration_since(UNIX_EPOCH)
      .map_err(|e| {
        FlowyError::internal().with_context(format!("Failed to get current timestamp: {}", e))
      })?
      .as_secs() as i64;

    let mut relation_map = WorkspaceRelationMap {
      workspace_id: workspace_id.to_string(),
      export_timestamp,
      ..Default::default()
    };

    for view in views {
      let view_metadata = self.extract_view_metadata(view).await?;
      relation_map.views.insert(view.id.clone(), view_metadata);
    }

    let view_ids: HashSet<String> = relation_map.views.keys().cloned().collect();
    for view_metadata in relation_map.views.values_mut() {
      view_metadata
        .children
        .retain(|child_id| view_ids.contains(child_id));
    }

    for view in views {
      let dependencies = self.find_view_dependencies(view, views).await?;
      relation_map.dependencies.extend(dependencies);
    }

    for view in views {
      let collab_object_id = self.calculate_collab_object_id(view).await?;
      let collab_metadata = CollabMetadata {
        object_id: collab_object_id.clone(),
        collab_type: self.get_collab_type_for_view(view),
        size_bytes: 0,
      };
      relation_map
        .collab_objects
        .insert(collab_object_id, collab_metadata);
    }

    info!(
      "Built relation map with {} views, {} collab objects, {} dependencies",
      relation_map.views.len(),
      relation_map.collab_objects.len(),
      relation_map.dependencies.len()
    );

    Ok(relation_map)
  }

  #[instrument(level = "trace", skip(self, view), err)]
  async fn extract_view_metadata(&self, view: &Arc<View>) -> FlowyResult<ViewMetadata> {
    let uid = self.folder_manager.user.user_id()?;
    let lock = self
      .folder_manager
      .mutex_folder
      .load_full()
      .ok_or_else(folder_not_init_error)?;
    let folder = lock.read().await;

    let child_views = folder.get_views_belong_to(&view.id, uid);
    let children: Vec<String> = child_views.iter().map(|child| child.id.clone()).collect();
    let view_id = view.id.clone();
    let parent_id = if view.parent_view_id.is_empty() {
      None
    } else {
      Some(view.parent_view_id.clone())
    };
    let view_id_uuid: Uuid = view.id.parse()?;
    let collab_object_id = self
      .folder_manager
      .get_collab_object_id(&view_id_uuid, &view.layout)
      .await?;

    drop(folder);
    drop(lock);

    let view_metadata = ViewMetadata {
      view_id,
      name: view.name.clone(),
      layout: view.layout.clone(),
      parent_id,
      children,
      collab_object_id,
      created_at: view.created_at,
      updated_at: view.last_edited_time,
      extra: view.extra.clone(),
      icon: view.icon.clone(),
    };

    Ok(view_metadata)
  }

  #[instrument(level = "trace", skip(self, view, all_views), err)]
  async fn find_view_dependencies(
    &self,
    view: &Arc<View>,
    all_views: &[Arc<View>],
  ) -> FlowyResult<Vec<ViewDependency>> {
    let mut dependencies = Vec::new();

    if !view.parent_view_id.is_empty() && all_views.iter().any(|v| v.id == view.parent_view_id) {
      dependencies.push(ViewDependency {
        source_view_id: view.parent_view_id.clone(),
        target_view_id: view.id.clone(),
        dependency_type: DependencyType::DocumentReference,
      });
    }

    info!(
      "Found {} dependencies for view {} ({})",
      dependencies.len(),
      view.id,
      view.name
    );

    Ok(dependencies)
  }

  #[instrument(level = "trace", skip(self, view), err)]
  async fn calculate_collab_object_id(&self, view: &Arc<View>) -> FlowyResult<String> {
    Ok(view.id.clone())
  }

  fn get_collab_type_for_view(&self, view: &Arc<View>) -> collab_entity::CollabType {
    use collab_entity::CollabType;
    match view.layout {
      ViewLayout::Document => CollabType::Document,
      ViewLayout::Grid | ViewLayout::Board | ViewLayout::Calendar => CollabType::Database,
      _ => CollabType::Document,
    }
  }

  #[instrument(level = "debug", skip(self, relation_map), err)]
  pub async fn extract_collab_data(
    &self,
    relation_map: &mut WorkspaceRelationMap,
  ) -> FlowyResult<CollabDataExtractResult> {
    let mut collab_data = HashMap::new();
    let mut doc_state_to_json = HashMap::new();

    info!(
      "Starting collab data extraction for {} views",
      relation_map.views.len()
    );

    for (view_id, view_metadata) in &relation_map.views {
      if let Some(handler) = self
        .folder_manager
        .operation_handlers
        .get(&view_metadata.layout)
      {
        let view_uuid: Uuid = view_id.parse().map_err(|e| {
          FlowyError::internal().with_context(format!("Invalid view ID format: {}", e))
        })?;
        match handler
          .gather_publish_encode_collab(&self.folder_manager.user, &view_uuid)
          .await
        {
          Ok(encoded_collab_result) => match encoded_collab_result {
            GatherEncodedCollab::Document(encoded) => {
              info!(
                "Extracted document collab for view {} ({}), size: {} bytes",
                view_id,
                view_metadata.name,
                encoded.doc_state.len()
              );
              if let Some(doc_metadata) = relation_map.collab_objects.get_mut(view_id) {
                doc_metadata.size_bytes = encoded.doc_state.len() as u64;
              }

              collab_data.insert(
                format!("documents/{}.collab", view_id),
                encoded.doc_state.to_vec(),
              );

              doc_state_to_json.insert(
                format!("documents/{}.json", view_id),
                self.document_doc_state_to_document_data_json_string(
                  &view_id.to_string(),
                  encoded.doc_state.to_vec(),
                )?,
              );
            },
            GatherEncodedCollab::Database(database_collab) => {
              info!(
                "Extracted database collab for view {} ({}), {} rows, {} row documents",
                view_id,
                view_metadata.name,
                database_collab.database_row_encoded_collabs.len(),
                database_collab.database_row_document_encoded_collabs.len()
              );

              if let Some(db_metadata) = relation_map.collab_objects.get_mut(view_id) {
                db_metadata.size_bytes =
                  database_collab.database_encoded_collab.doc_state.len() as u64;
              }

              collab_data.insert(
                format!("databases/{}.collab", view_id),
                database_collab.database_encoded_collab.doc_state.to_vec(),
              );

              doc_state_to_json.insert(
                format!("databases/{}.json", view_id),
                self
                  .database_doc_state_to_database_data_json_string(
                    &view_id.to_string(),
                    database_collab.database_encoded_collab.doc_state.to_vec(),
                    &database_collab.database_row_encoded_collabs,
                  )
                  .await?,
              );

              println!(
                "database_collab.database_metas: {:?}",
                database_collab.database_metas
              );

              if let Some(ref mut database_meta) = relation_map.workspace_database_meta {
                database_meta.extend(database_collab.database_metas.clone().into_iter().map(
                  |meta| WorkspaceDatabaseMeta {
                    database_id: meta.database_id,
                    view_ids: meta.linked_views,
                  },
                ));
              }

              let mut row_ids: HashMap<String, String> = HashMap::new();
              for (row_id, row_encoded) in database_collab.database_row_encoded_collabs {
                let row_uuid = row_id.clone();
                let row_document_id = database_row_document_id_from_row_id(&row_id);
                row_ids.insert(row_document_id.clone(), row_uuid.clone());

                let row_metadata = CollabMetadata {
                  object_id: row_uuid.clone(),
                  collab_type: CollabType::DatabaseRow,
                  size_bytes: row_encoded.doc_state.len() as u64,
                };
                relation_map
                  .collab_objects
                  .insert(row_uuid.clone(), row_metadata);

                let db_to_row_dependency = ViewDependency {
                  source_view_id: view_id.clone(),
                  target_view_id: row_uuid,
                  dependency_type: DependencyType::DatabaseRow,
                };
                relation_map.dependencies.push(db_to_row_dependency);

                collab_data.insert(
                  format!("databases/{}/rows/{}.collab", view_id, row_id),
                  row_encoded.doc_state.to_vec(),
                );
              }

              for (row_document_id, row_doc_encoded) in
                database_collab.database_row_document_encoded_collabs
              {
                let row_document_uuid = row_document_id.clone();
                let row_doc_metadata = CollabMetadata {
                  object_id: row_document_uuid.clone(),
                  collab_type: CollabType::Document,
                  size_bytes: row_doc_encoded.doc_state.len() as u64,
                };
                relation_map
                  .collab_objects
                  .insert(row_document_uuid.clone(), row_doc_metadata);

                if let Some(row_id) = row_ids.get(&row_document_uuid) {
                  let row_to_doc_dependency = ViewDependency {
                    source_view_id: row_id.clone(),
                    target_view_id: row_document_uuid,
                    dependency_type: DependencyType::DatabaseRowDocument,
                  };
                  relation_map.dependencies.push(row_to_doc_dependency);
                }

                collab_data.insert(
                  format!(
                    "databases/{}/row_documents/{}.collab",
                    view_id, row_document_id
                  ),
                  row_doc_encoded.doc_state.to_vec(),
                );

                doc_state_to_json.insert(
                  format!(
                    "databases/{}/row_documents/{}.json",
                    view_id, row_document_id
                  ),
                  self.document_doc_state_to_document_data_json_string(
                    &row_document_id.to_string(),
                    row_doc_encoded.doc_state.to_vec(),
                  )?,
                );
              }
            },
            GatherEncodedCollab::Unknown => {
              info!(
                "Unknown collab type for view {} ({}), skipping",
                view_id, view_metadata.name
              );
            },
          },
          Err(e) => {
            error!(
              "Failed to extract collab data for view {} ({}): {}",
              view_id, view_metadata.name, e
            );
          },
        }
      } else {
        error!(
          "No operation handler found for view {} with layout {:?}",
          view_id, view_metadata.layout
        );
      }
    }

    info!(
      "Completed collab data extraction: {} files extracted",
      collab_data.len()
    );

    Ok((collab_data, doc_state_to_json))
  }

  fn document_doc_state_to_document_data_json_string(
    &self,
    doc_id: &str,
    doc_state: Vec<u8>,
  ) -> FlowyResult<String> {
    let client_id = default_client_id();
    let options = CollabOptions::new(doc_id.to_string(), client_id)
      .with_data_source(DataSource::DocStateV1(doc_state));
    let collab = Collab::new_with_options(CollabOrigin::Empty, options).map_err(|e| {
      FlowyError::internal().with_context(format!("Failed to create collab: {}", e))
    })?;
    let document = Document::open(collab)?;
    let document_data = document.get_document_data()?;
    Ok(serde_json::to_string_pretty(&document_data)?)
  }

  async fn database_doc_state_to_database_data_json_string(
    &self,
    database_id: &str,
    doc_state: Vec<u8>,
    row_encoded_collabs: &HashMap<String, EncodedCollab>,
  ) -> FlowyResult<String> {
    let client_id = default_client_id();

    let data_source = DataSource::DocStateV1(doc_state);
    let options =
      CollabOptions::new(database_id.to_string(), client_id).with_data_source(data_source);
    let collab = Collab::new_with_options(CollabOrigin::Empty, options).map_err(|e| {
      FlowyError::internal().with_context(format!("Failed to create collab: {}", e))
    })?;

    let cache = Arc::new(DashMap::new());

    for (row_id, row_encoded) in row_encoded_collabs {
      let row_options = CollabOptions::new(row_id.to_string(), client_id)
        .with_data_source(DataSource::DocStateV1(row_encoded.doc_state.to_vec()));
      if let Ok(mut row_collab) = Collab::new_with_options(CollabOrigin::Empty, row_options) {
        let row_id_typed = RowId::from(row_id.to_string());
        if let Ok(row_body) = DatabaseRowBody::open(row_id_typed.clone(), &mut row_collab) {
          let database_row = DatabaseRow {
            row_id: row_id_typed.clone(),
            collab: row_collab,
            body: row_body,
          };
          cache.insert(row_id_typed, Arc::new(RwLock::new(database_row)));
        }
      }
    }

    let collab_service = Arc::new(NoPersistenceDatabaseCollabService::new_with_cache(
      client_id, cache,
    ));

    let database_body = DatabaseBody::from_collab(&collab, collab_service.clone(), None)
      .ok_or_else(|| FlowyError::internal().with_context("Cannot parse database from collab"))?;
    let database = Database {
      collab,
      body: database_body,
      collab_service,
    };
    let database_data = database.get_database_data(20, false).await;
    Ok(serde_json::to_string_pretty(&database_data)?)
  }

  fn extract_local_files_from_json(&self, json_content: &str) -> Vec<(String, String)> {
    let regex = Regex::new(r#"\\"url\\":\\"(/[^"\\]+)\\""#).unwrap();
    let mut local_files = Vec::new();

    for cap in regex.captures_iter(json_content) {
      if let Some(path) = cap.get(1) {
        let file_path = path.as_str();
        let path_obj = std::path::Path::new(file_path);

        if path_obj.is_absolute() && path_obj.is_file() {
          if let Some(filename) = path_obj.file_name() {
            local_files.push((
              file_path.to_string(),
              filename.to_string_lossy().to_string(),
            ));
          }
        }
      }
    }

    let regex2 = Regex::new(r#""url"\s*:\s*"(/[^"]+)"#).unwrap();
    for cap in regex2.captures_iter(json_content) {
      if let Some(path) = cap.get(1) {
        let file_path = path.as_str();
        let path_obj = std::path::Path::new(file_path);

        if path_obj.is_absolute() && path_obj.is_file() {
          if let Some(filename) = path_obj.file_name() {
            local_files.push((
              file_path.to_string(),
              filename.to_string_lossy().to_string(),
            ));
          }
        }
      }
    }

    local_files
  }

  async fn collect_all_local_files(
    &self,
    doc_state_to_json: &mut HashMap<String, String>,
    relation_map: &mut WorkspaceRelationMap,
  ) -> FlowyResult<HashMap<String, Vec<u8>>> {
    let mut local_files_map = HashMap::new();
    let mut path_to_file_id: HashMap<String, String> = HashMap::new();

    for (json_path, json_content) in doc_state_to_json.iter_mut() {
      let local_files = self.extract_local_files_from_json(json_content);

      let source_id = if json_path.starts_with("documents/") {
        // documents
        json_path
          .strip_prefix("documents/")
          .and_then(|s| s.strip_suffix(".json"))
          .unwrap_or("")
      } else if json_path.contains("/row_documents/") {
        // row_documents
        json_path
          .split("/row_documents/")
          .nth(1)
          .and_then(|s| s.strip_suffix(".json"))
          .unwrap_or("")
      } else if json_path.starts_with("databases/") && !json_path.contains("/row_documents/") {
        // databases
        json_path
          .strip_prefix("databases/")
          .and_then(|s| s.strip_suffix(".json"))
          .unwrap_or("")
      } else {
        continue;
      };

      let mut updated_json = json_content.clone();

      for (original_path, _filename) in local_files {
        let file_id = if let Some(existing_filename) = path_to_file_id.get(&original_path) {
          existing_filename.clone()
        } else {
          let path = PathBuf::from(original_path.clone());
          let file_id = FileId::from_path(&path).await?;
          path_to_file_id.insert(original_path.clone(), file_id.clone());
          match fs::read(&original_path) {
            Ok(file_content) => {
              local_files_map.insert(file_id.clone(), file_content);
              let file_dependency = ViewDependency {
                source_view_id: source_id.to_string(),
                target_view_id: file_id.clone(),
                dependency_type: DependencyType::FileAttachment,
              };
              relation_map.dependencies.push(file_dependency);
            },
            Err(e) => {
              error!("Failed to read local file '{}': {}", original_path, e);
              continue;
            },
          }

          file_id
        };

        let new_url = format!("{}/{}", source_id, &file_id);
        updated_json = updated_json.replace(&original_path, &new_url);
      }

      *json_content = updated_json;
    }

    Ok(local_files_map)
  }
}
