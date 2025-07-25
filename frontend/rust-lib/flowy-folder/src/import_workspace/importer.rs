use flowy_error::FlowyResult;

use super::types::{FolderImportContext, FolderWorkspaceImporter, ImportRequest};

impl<'a> FolderWorkspaceImporter<'a> {
  pub fn new(folder_manager: &'a crate::manager::FolderManager) -> Self {
    Self { folder_manager }
  }

  /// Import a workspace
  ///
  /// 1. we need to unzip the archive
  /// 2. build the import plan
  ///   2.1 parse the metadata
  ///   2.2 parse the relation map
  /// 3. execute the import plan
  ///   3.1 create the workspace
  ///   3.2 create the views in order. The order is very important because some views may depend on other views.
  /// 4. cleanup the temp dir
  pub async fn import_workspace(&self, request: ImportRequest) -> FlowyResult<String> {
    let temp_dir = self.extract_archive(&request.archive_path).await?;

    // todo: simple validation, we need to check all the metadata and relation map are valid.
    self.validate(&temp_dir).await?;

    let metadata = self.parse_metadata(&temp_dir).await?;
    let relation_map = self.parse_relation_map(&temp_dir).await?;

    let import_plan = self
      .generate_import_plan(metadata, relation_map, request.new_workspace_name)
      .await?;

    let new_workspace_id = self
      .execute_import_plan(import_plan, temp_dir.clone())
      .await?;

    self.cleanup_temp_dir(temp_dir).await?;

    Ok(new_workspace_id)
  }

  async fn execute_import_plan(
    &self,
    import_plan: super::types::FolderImportPlan,
    temp_dir: String,
  ) -> FlowyResult<String> {
    let mut import_context = FolderImportContext::new(temp_dir);

    let workspace_id = self
      .create_workspace(&import_plan.workspace_metadata, &mut import_context)
      .await?;

    self
      .create_views_in_order(&import_plan, &mut import_context)
      .await?;

    Ok(workspace_id)
  }
}
