use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use uuid::Uuid;

use crate::manager::FolderManager;
use collab_importer::workspace::entities::{ViewDependency, ViewMetadata};

pub struct FolderWorkspaceImporter<'a> {
  pub folder_manager: &'a FolderManager,
}

#[derive(Debug, Clone)]
pub struct ImportRequest {
  pub archive_path: String,
  pub new_workspace_name: Option<String>,
}

#[derive(Debug, Clone, Default)]
pub struct FolderIdMapping {
  pub workspace_id_map: HashMap<String, String>,
  pub view_id_map: HashMap<String, String>,
}

#[derive(Debug, Clone)]
pub struct FolderImportPlan {
  pub workspace_metadata: FolderWorkspaceMetadata,
  pub view_hierarchy: Vec<FolderViewImportItem>,
  pub dependencies: Vec<ViewDependency>,
  pub id_mapping: FolderIdMapping,
}

#[derive(Debug, Clone)]
pub struct FolderViewImportItem {
  pub original_id: String,
  pub new_id: String,
  pub view_metadata: ViewMetadata,
  pub collab_data_path: String,
  pub dependencies: Vec<String>,
  pub import_order: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FolderWorkspaceMetadata {
  pub workspace_id: Uuid,
  pub name: String,
  pub created_at: i64,
}

#[derive(Debug, Clone)]
pub struct FolderImportContext {
  pub temp_dir: String,
  pub created_resources: Vec<FolderCreatedResource>,
}

#[derive(Debug, Clone)]
pub enum FolderCreatedResource {
  Workspace(String),
  View(String),
  CollabObject(String),
}

impl FolderIdMapping {
  pub fn new() -> Self {
    Self::default()
  }

  pub fn add_workspace_mapping(&mut self, original_id: Uuid, new_id: Uuid) {
    self
      .workspace_id_map
      .insert(original_id.to_string(), new_id.to_string());
  }

  pub fn add_view_mapping(&mut self, original_id: Uuid, new_id: Uuid) {
    self
      .view_id_map
      .insert(original_id.to_string(), new_id.to_string());
  }

  pub fn get_new_workspace_id(&self, original_id: &str) -> Option<String> {
    self.workspace_id_map.get(original_id).cloned()
  }

  pub fn get_new_view_id(&self, original_id: &str) -> Option<String> {
    // if the original id is a workspace id, return the workspace id
    // for testing, we don't return the new id for the workspace id, using the original id instead.
    if self.workspace_id_map.contains_key(original_id) {
      return Some(original_id.to_string());
    }

    self.view_id_map.get(original_id).cloned()
  }
}

impl FolderImportPlan {
  pub fn new(workspace_metadata: FolderWorkspaceMetadata, id_mapping: FolderIdMapping) -> Self {
    Self {
      workspace_metadata,
      view_hierarchy: Vec::new(),
      dependencies: Vec::new(),
      id_mapping,
    }
  }

  pub fn add_view_item(&mut self, item: FolderViewImportItem) {
    self.view_hierarchy.push(item);
  }

  pub fn sort_by_import_order(&mut self) {
    self.view_hierarchy.sort_by_key(|item| item.import_order);
  }

  pub fn get_root_views(&self) -> Vec<&FolderViewImportItem> {
    self
      .view_hierarchy
      .iter()
      .filter(|item| item.view_metadata.parent_id.is_none())
      .collect()
  }

  pub fn get_children_of(&self, parent_id: &Uuid) -> Vec<&FolderViewImportItem> {
    self
      .view_hierarchy
      .iter()
      .filter(|item| {
        item
          .view_metadata
          .parent_id
          .as_ref()
          .map(|pid| pid == &parent_id.to_string())
          .unwrap_or(false)
      })
      .collect()
  }

  pub fn total_import_steps(&self) -> usize {
    1 + self.view_hierarchy.len() + 1 + 1
  }
}

impl FolderImportContext {
  pub fn new(temp_dir: String) -> Self {
    Self {
      temp_dir,
      created_resources: Vec::new(),
    }
  }

  pub fn track_created_resource(&mut self, resource: FolderCreatedResource) {
    self.created_resources.push(resource);
  }
}
