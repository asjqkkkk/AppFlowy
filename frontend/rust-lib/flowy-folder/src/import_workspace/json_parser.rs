use std::fs::read_to_string;

use flowy_error::{FlowyError, FlowyResult};

use super::types::FolderWorkspaceImporter;
use collab_importer::workspace::entities::WorkspaceRelationMap;

impl<'a> FolderWorkspaceImporter<'a> {
  pub async fn parse_metadata(&self, temp_dir: &str) -> FlowyResult<serde_json::Value> {
    let metadata_path = format!("{}/metadata.json", temp_dir);

    let metadata_content = read_to_string(&metadata_path).map_err(|e| {
      FlowyError::internal().with_context(format!("Failed to read metadata.json: {}", e))
    })?;

    let metadata: serde_json::Value = serde_json::from_str(&metadata_content).map_err(|e| {
      FlowyError::invalid_data().with_context(format!("Failed to parse metadata.json: {}", e))
    })?;

    self.validate_metadata(&metadata)?;

    Ok(metadata)
  }

  fn validate_metadata(&self, metadata: &serde_json::Value) -> FlowyResult<()> {
    let export_info = metadata.get("export_info").ok_or_else(|| {
      FlowyError::invalid_data().with_context("Missing export_info section in metadata")
    })?;

    let workspace_id = export_info.get("workspace_id").ok_or_else(|| {
      FlowyError::invalid_data().with_context("Missing workspace_id in export_info")
    })?;

    if !workspace_id.is_string() {
      return Err(FlowyError::invalid_data().with_context("workspace_id must be a string"));
    }

    let version = export_info
      .get("version")
      .ok_or_else(|| FlowyError::invalid_data().with_context("Missing version in export_info"))?;

    let version_str = version
      .as_str()
      .ok_or_else(|| FlowyError::invalid_data().with_context("Version must be a string"))?;

    if version_str != "1.0" {
      return Err(FlowyError::invalid_data().with_context(format!(
        "Unsupported export version: {}. Expected: 1.0",
        version_str
      )));
    }

    Ok(())
  }

  pub async fn parse_relation_map(&self, temp_dir: &str) -> FlowyResult<WorkspaceRelationMap> {
    let relation_map_path = format!("{}/relation_map.json", temp_dir);

    tracing::info!("Parsing relation map from: {}", relation_map_path);

    let relation_map_content = std::fs::read_to_string(&relation_map_path).map_err(|e| {
      FlowyError::internal().with_context(format!("Failed to read relation_map.json: {}", e))
    })?;

    let relation_map: WorkspaceRelationMap =
      serde_json::from_str(&relation_map_content).map_err(|e| {
        FlowyError::invalid_data().with_context(format!("Failed to parse relation_map.json: {}", e))
      })?;

    self.validate_relation_map(&relation_map)?;

    Ok(relation_map)
  }

  fn validate_relation_map(&self, relation_map: &WorkspaceRelationMap) -> FlowyResult<()> {
    if relation_map.workspace_id.to_string().is_empty() {
      return Err(FlowyError::invalid_data().with_context("Empty workspace_id in relation map"));
    }

    if relation_map.views.is_empty() {
      return Err(FlowyError::invalid_data().with_context("No views found in relation map"));
    }

    for (view_id, view_metadata) in &relation_map.views {
      if view_metadata.view_id != *view_id {
        return Err(FlowyError::invalid_data().with_context(format!(
          "View ID mismatch: key={}, view.view_id={}",
          view_id, view_metadata.view_id
        )));
      }

      if let Some(parent_id) = &view_metadata.parent_id {
        // for the top level view, the parent id is the workspace id
        if !relation_map.views.contains_key(parent_id) && relation_map.workspace_id != *parent_id {
          return Err(FlowyError::invalid_data().with_context(format!(
            "View {} references non-existent parent {}",
            view_id, parent_id
          )));
        }
      }

      for child_id in &view_metadata.children {
        if !relation_map.views.contains_key(child_id) {
          return Err(FlowyError::invalid_data().with_context(format!(
            "View {} references non-existent child {}",
            view_id, child_id
          )));
        }
      }

      if !relation_map
        .collab_objects
        .contains_key(&view_metadata.collab_object_id)
      {
        return Err(FlowyError::invalid_data().with_context(format!(
          "View {} references non-existent collab object {}",
          view_id, view_metadata.collab_object_id
        )));
      }
    }

    for dependency in &relation_map.dependencies {
      if !relation_map.views.contains_key(&dependency.source_view_id) {
        return Err(FlowyError::invalid_data().with_context(format!(
          "Dependency references non-existent source view {}",
          dependency.source_view_id
        )));
      }

      if !relation_map.views.contains_key(&dependency.target_view_id) {
        return Err(FlowyError::invalid_data().with_context(format!(
          "Dependency references non-existent target view {}",
          dependency.target_view_id
        )));
      }
    }

    Ok(())
  }
}
