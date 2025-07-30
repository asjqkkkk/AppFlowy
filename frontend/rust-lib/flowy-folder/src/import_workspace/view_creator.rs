use std::fs::read;
use uuid::Uuid;

use flowy_error::{FlowyError, FlowyResult};

use super::types::{
  FolderCreatedResource, FolderImportContext, FolderImportPlan, FolderViewImportItem,
  FolderWorkspaceImporter,
};
use crate::entities::{CreateViewParams, ViewLayoutPB, ViewSectionPB};
use crate::view_operation::ViewData;

impl FolderWorkspaceImporter<'_> {
  // todo: this function is incorrect, it doesn't create a new workspace. it use the current workspace instead.
  pub async fn create_workspace(
    &self,
    workspace_metadata: &super::types::FolderWorkspaceMetadata,
    import_context: &mut FolderImportContext,
  ) -> FlowyResult<String> {
    let workspace_id = workspace_metadata.workspace_id.to_string();

    import_context.track_created_resource(FolderCreatedResource::Workspace(workspace_id.clone()));
    // we should create a new workspace here
    Ok(workspace_id)
  }

  pub async fn create_views_in_order(
    &self,
    import_plan: &FolderImportPlan,
    import_context: &mut FolderImportContext,
  ) -> FlowyResult<()> {
    for view_item in &import_plan.view_hierarchy {
      self
        .create_single_view(view_item, import_plan, import_context)
        .await?;
    }
    Ok(())
  }

  pub async fn create_single_view(
    &self,
    view_item: &FolderViewImportItem,
    import_plan: &FolderImportPlan,
    import_context: &mut FolderImportContext,
  ) -> FlowyResult<()> {
    let collab_data = self
      .load_collab_object_data(&view_item.collab_data_path, import_context)
      .await?;

    let view_id = self
      .create_view_with_data(view_item, &collab_data, import_plan)
      .await?;

    import_context.track_created_resource(FolderCreatedResource::View(view_id.clone()));

    Ok(())
  }

  pub async fn load_collab_object_data(
    &self,
    collab_data_path: &str,
    import_context: &FolderImportContext,
  ) -> FlowyResult<Vec<u8>> {
    let full_path = format!("{}/{}", import_context.temp_dir, collab_data_path);

    // for empty documents, the collab file might not be included in the archive
    if !std::path::Path::new(&full_path).exists() {
      return Ok(Vec::new());
    }

    let collab_bytes = read(&full_path).map_err(|e| {
      FlowyError::internal().with_context(format!(
        "Failed to read collab object file '{}': {}",
        full_path, e
      ))
    })?;

    Ok(collab_bytes)
  }

  // todo: this function is incorrect, it doesn't create a new view with the provided data.
  pub async fn create_view_with_data(
    &self,
    view_item: &FolderViewImportItem,
    collab_data: &[u8],
    import_plan: &FolderImportPlan,
  ) -> FlowyResult<String> {
    let parent_view_id = if let Some(original_parent_id) = &view_item.view_metadata.parent_id {
      let mapped_id = import_plan
        .id_mapping
        .get_new_view_id(&original_parent_id.to_string())
        .ok_or_else(|| FlowyError::internal().with_context("Missing parent ID mapping"))?;

      // debug code: remove it later
      if mapped_id == *original_parent_id {
        self.folder_manager.user.workspace_id()?
      } else {
        Uuid::parse_str(&mapped_id)
          .map_err(|e| FlowyError::internal().with_context(format!("Invalid parent UUID: {}", e)))?
      }
    } else {
      return Err(FlowyError::internal().with_context("Missing parent ID"));
    };

    let view_id = Uuid::parse_str(&view_item.new_id)
      .map_err(|e| FlowyError::internal().with_context(format!("Invalid view UUID: {}", e)))?;

    let layout = match view_item.view_metadata.layout {
      collab_folder::ViewLayout::Document => ViewLayoutPB::Document,
      collab_folder::ViewLayout::Grid => ViewLayoutPB::Grid,
      collab_folder::ViewLayout::Board => ViewLayoutPB::Board,
      collab_folder::ViewLayout::Calendar => ViewLayoutPB::Calendar,
      collab_folder::ViewLayout::Chat => ViewLayoutPB::Chat,
    };

    let _collab_bytes = collab_data.to_owned();

    // fixme: get the initial data from the collab data.
    let initial_data = ViewData::Empty;

    // handle the public and private section here if we get the extra value.
    let create_params = CreateViewParams {
      parent_view_id,
      name: view_item.view_metadata.name.clone(),
      layout,
      view_id,
      initial_data,
      set_as_current: false,
      index: None,
      section: Some(ViewSectionPB::Public),
      icon: view_item.view_metadata.icon.clone(),
      extra: view_item.view_metadata.extra.clone(),
    };

    // remove this log
    println!("create_params: {:?}", create_params);

    let created_view = self
      .folder_manager
      .create_view_with_params(create_params, true)
      .await?;

    Ok(created_view.id.to_string())
  }
}
