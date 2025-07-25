use flowy_derive::{ProtoBuf, ProtoBuf_Enum};
use uuid::Uuid;

#[derive(Debug, Clone)]
pub struct ExportRequest {
  pub workspace_id: Uuid,
  pub output_path: String,
}

#[derive(Debug, Clone, ProtoBuf, Default)]
pub struct ExportWorkspaceRequestPB {
  #[pb(index = 1)]
  pub workspace_id: String,

  #[pb(index = 2)]
  pub output_path: String,
}

#[derive(Debug, Clone, ProtoBuf, Default)]
pub struct ExportProgressResponsePB {
  #[pb(index = 1)]
  pub task_id: String,

  #[pb(index = 2)]
  pub output_file_path: String,
}

#[derive(ProtoBuf_Enum, Clone, Debug, PartialEq, Eq, Default)]
pub enum DependencyTypePB {
  #[default]
  // Add a prefix to fix these errors: "DatabaseRelation" is already defined
  DTDocumentReference = 0,
  DTDatabaseRow = 1,
  DTDatabaseRelation = 2,
  DTFileAttachment = 3,
  DTDatabaseRowDocument = 4,
}

#[derive(Debug, Clone, ProtoBuf, Default)]
pub struct ImportWorkspaceRequestPB {
  #[pb(index = 1)]
  pub archive_path: String,

  #[pb(index = 2)]
  pub new_workspace_name: String,
}

#[derive(Debug, Clone, ProtoBuf, Default)]
pub struct ImportWorkspaceResponsePB {
  #[pb(index = 1)]
  pub workspace_id: String,
}
