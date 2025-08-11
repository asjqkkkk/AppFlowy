use client_api::entity::{CreateExportTask, CreateExportTaskResponse};
use flowy_derive::{ProtoBuf, ProtoBuf_Enum};
use uuid::Uuid;
use validator::Validate;

#[derive(Debug, Clone)]
pub struct ExportRequest {
  pub workspace_id: Uuid,
  pub output_path: String,
  pub include_file_attachments: bool,
}

#[derive(Debug, Clone, ProtoBuf, Default)]
pub struct ExportWorkspaceRequestPB {
  #[pb(index = 1)]
  pub workspace_id: String,

  #[pb(index = 2)]
  pub output_path: String,

  #[pb(index = 3)]
  pub include_file_attachments: bool,
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

#[derive(Debug, Clone, ProtoBuf, Validate, Default)]
pub struct CreateExportRequestPB {
  #[pb(index = 1, one_of)]
  pub include_file_attachments: Option<bool>,
}

#[derive(Debug, Clone, ProtoBuf, Default)]
pub struct CreateExportResponsePB {
  #[pb(index = 1)]
  pub task_id: String,
}

impl From<CreateExportTask> for CreateExportRequestPB {
  fn from(task: CreateExportTask) -> Self {
    CreateExportRequestPB {
      include_file_attachments: task.include_file_attachments,
    }
  }
}

impl From<CreateExportRequestPB> for CreateExportTask {
  fn from(pb: CreateExportRequestPB) -> Self {
    CreateExportTask {
      include_file_attachments: pb.include_file_attachments,
    }
  }
}

impl From<CreateExportTaskResponse> for CreateExportResponsePB {
  fn from(response: CreateExportTaskResponse) -> Self {
    CreateExportResponsePB {
      task_id: response.task_id,
    }
  }
}
