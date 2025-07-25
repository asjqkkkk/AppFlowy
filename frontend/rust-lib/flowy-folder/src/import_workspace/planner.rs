use collab_folder::timestamp;
use std::collections::HashMap;
use uuid::Uuid;

use flowy_error::{FlowyError, FlowyResult};

use super::types::{
  FolderIdMapping, FolderImportPlan, FolderViewImportItem, FolderWorkspaceImporter,
  FolderWorkspaceMetadata,
};
use collab_importer::workspace::entities::WorkspaceRelationMap;

impl<'a> FolderWorkspaceImporter<'a> {
  pub async fn generate_import_plan(
    &self,
    _metadata: serde_json::Value,
    relation_map: WorkspaceRelationMap,
    workspace_name: Option<String>,
  ) -> FlowyResult<FolderImportPlan> {
    let new_workspace_id = Uuid::new_v4();
    let workspace_name = workspace_name.unwrap_or("Workspace".to_string());

    let workspace_metadata = FolderWorkspaceMetadata {
      workspace_id: new_workspace_id,
      name: workspace_name,
      created_at: timestamp(),
    };

    let mut id_mapping = FolderIdMapping::new();

    id_mapping.add_workspace_mapping(
      relation_map.workspace_id.parse().unwrap_or_else(|_| Uuid::new_v4()),
      new_workspace_id,
    );

    for view_id in relation_map.views.keys() {
      let new_view_id = Uuid::new_v4();
      id_mapping.add_view_mapping(
        view_id.parse().unwrap_or_else(|_| Uuid::new_v4()),
        new_view_id,
      );
    }

    let mut import_plan = FolderImportPlan::new(workspace_metadata, id_mapping);

    let view_items = self
      .process_view_hierarchy(&relation_map, &import_plan.id_mapping)
      .await?;

    for item in view_items {
      import_plan.add_view_item(item);
    }

    import_plan.dependencies = relation_map.dependencies.clone();

    Ok(import_plan)
  }

  // we need to import the parent view first, then the children views because the children views can't be created without parent_id
  pub async fn process_view_hierarchy(
    &self,
    relation_map: &WorkspaceRelationMap,
    id_mapping: &FolderIdMapping,
  ) -> FlowyResult<Vec<FolderViewImportItem>> {
    let mut import_items = Vec::new();
    let mut import_order = 0;

    let mut dependency_graph = HashMap::new();
    let mut in_degree = HashMap::new();

    dependency_graph.insert(relation_map.workspace_id.clone(), Vec::new());
    in_degree.insert(relation_map.workspace_id.clone(), 0);

    for view_id in relation_map.views.keys() {
      dependency_graph.insert(view_id.clone(), Vec::new());
      in_degree.insert(view_id.clone(), 0);
    }

    for (view_id, view_metadata) in &relation_map.views {
      if let Some(parent_id) = &view_metadata.parent_id {
        dependency_graph.get_mut(parent_id).unwrap().push(view_id.clone());
        *in_degree.get_mut(view_id).unwrap() += 1;
      }

      for dependency in &relation_map.dependencies {
        if dependency.target_view_id == *view_id {
          dependency_graph
            .get_mut(&dependency.source_view_id)
            .unwrap()
            .push(view_id.clone());
          *in_degree.get_mut(view_id).unwrap() += 1;
        }
      }
    }

    let mut queue = std::collections::VecDeque::new();

    for (view_id, degree) in &in_degree {
      if *degree == 0 {
        queue.push_back(view_id.clone());
      }
    }

    while let Some(current_view_id) = queue.pop_front() {
      // workspace id is a special case, it's not a view, but it's the root of the view hierarchy
      if current_view_id == relation_map.workspace_id {
        for dependent_view_id in dependency_graph.get(&current_view_id).unwrap() {
          let current_degree = in_degree.get_mut(dependent_view_id).unwrap();
          *current_degree -= 1;

          if *current_degree == 0 {
            queue.push_back(dependent_view_id.clone());
          }
        }
        continue;
      }

      let view_metadata = relation_map.views.get(&current_view_id).unwrap();

      // chat is not supported, we skip it
      if view_metadata.layout == collab_folder::ViewLayout::Chat {
        for dependent_view_id in dependency_graph.get(&current_view_id).unwrap() {
          let current_degree = in_degree.get_mut(dependent_view_id).unwrap();
          *current_degree -= 1;

          if *current_degree == 0 {
            queue.push_back(dependent_view_id.clone());
          }
        }
        continue;
      }

      let new_view_id = id_mapping
        .get_new_view_id(&current_view_id.to_string())
        .ok_or_else(|| FlowyError::internal().with_context("Missing view ID mapping"))?;

      let collab_object_id = &view_metadata.collab_object_id;
      // Determine the correct path based on view layout
      let collab_data_path = match view_metadata.layout {
        // Document layout
        collab_folder::ViewLayout::Document => {
          format!("collab_objects/documents/{}.collab", collab_object_id)
        },
        // Database layouts (Grid, Board, Calendar)
        collab_folder::ViewLayout::Grid
        | collab_folder::ViewLayout::Board
        | collab_folder::ViewLayout::Calendar => {
          format!("collab_objects/databases/{}.collab", collab_object_id)
        },
        // Default to document for unknown layouts
        _ => format!("collab_objects/documents/{}.collab", collab_object_id),
      };

      let mut mapped_dependencies = Vec::new();
      for dependency in &relation_map.dependencies {
        if dependency.target_view_id == current_view_id {
          if let Some(new_source_id) =
            id_mapping.get_new_view_id(&dependency.source_view_id.to_string())
          {
            mapped_dependencies.push(new_source_id.clone());
          }
        }
      }

      let import_item = FolderViewImportItem {
        original_id: current_view_id.to_string(),
        new_id: new_view_id.clone(),
        view_metadata: view_metadata.clone(),
        collab_data_path,
        dependencies: mapped_dependencies,
        import_order,
      };

      import_items.push(import_item);
      import_order += 1;

      for dependent_view_id in dependency_graph.get(&current_view_id).unwrap() {
        let current_degree = in_degree.get_mut(dependent_view_id).unwrap();
        *current_degree -= 1;

        if *current_degree == 0 {
          queue.push_back(dependent_view_id.clone());
        }
      }
    }

    Ok(import_items)
  }
}
