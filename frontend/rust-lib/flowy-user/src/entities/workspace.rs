use client_api::entity::billing_dto::WorkspaceUsageAndLimit;
use client_api::v2::ConnectState;
use validator::Validate;

use flowy_derive::{ProtoBuf, ProtoBuf_Enum};
use flowy_user_pub::cloud::{AFWorkspaceSettings, AFWorkspaceSettingsChange};
use flowy_user_pub::entities::{
  AuthProvider, Role, WorkspaceInvitation, WorkspaceMember, WorkspaceType,
};
use lib_infra::validator_fn::required_not_empty_str;

#[derive(ProtoBuf, Default, Clone)]
pub struct WorkspaceMemberPB {
  #[pb(index = 1)]
  pub email: String,

  #[pb(index = 2)]
  pub name: String,

  #[pb(index = 3)]
  pub role: AFRolePB,

  #[pb(index = 4, one_of)]
  pub avatar_url: Option<String>,

  #[pb(index = 5, one_of)]
  pub joined_at: Option<i64>,
}

impl From<WorkspaceMember> for WorkspaceMemberPB {
  fn from(value: WorkspaceMember) -> Self {
    Self {
      email: value.email,
      name: value.name,
      role: value.role.into(),
      avatar_url: value.avatar_url,
      joined_at: value.joined_at,
    }
  }
}

#[derive(ProtoBuf, Default, Clone)]
pub struct RepeatedWorkspaceMemberPB {
  #[pb(index = 1)]
  pub items: Vec<WorkspaceMemberPB>,
}

#[derive(ProtoBuf, Default, Clone, Validate)]
pub struct WorkspaceMemberInvitationPB {
  #[pb(index = 1)]
  #[validate(custom(function = "required_not_empty_str"))]
  pub workspace_id: String,

  #[pb(index = 2)]
  #[validate(email)]
  pub invitee_email: String,

  #[pb(index = 3)]
  pub role: AFRolePB,
}

#[derive(Debug, ProtoBuf, Default, Clone)]
pub struct RepeatedWorkspaceInvitationPB {
  #[pb(index = 1)]
  pub items: Vec<WorkspaceInvitationPB>,
}

#[derive(Debug, ProtoBuf, Default, Clone)]
pub struct WorkspaceInvitationPB {
  #[pb(index = 1)]
  pub invite_id: String,
  #[pb(index = 2)]
  pub workspace_id: String,
  #[pb(index = 3)]
  pub workspace_name: String,
  #[pb(index = 4)]
  pub inviter_email: String,
  #[pb(index = 5)]
  pub inviter_name: String,
  #[pb(index = 6)]
  pub status: String,
  #[pb(index = 7)]
  pub updated_at_timestamp: i64,
}

impl From<WorkspaceInvitation> for WorkspaceInvitationPB {
  fn from(value: WorkspaceInvitation) -> Self {
    Self {
      invite_id: value.invite_id.to_string(),
      workspace_id: value.workspace_id.to_string(),
      workspace_name: value.workspace_name.unwrap_or_default(),
      inviter_email: value.inviter_email.unwrap_or_default(),
      inviter_name: value.inviter_name.unwrap_or_default(),
      status: format!("{:?}", value.status),
      updated_at_timestamp: value.updated_at.timestamp(),
    }
  }
}

#[derive(ProtoBuf, Default, Clone, Validate)]
pub struct AcceptWorkspaceInvitationPB {
  #[pb(index = 1)]
  #[validate(custom(function = "required_not_empty_str"))]
  pub invite_id: String,
}

// Deprecated
#[derive(ProtoBuf, Default, Clone, Validate)]
pub struct AddWorkspaceMemberPB {
  #[pb(index = 1)]
  #[validate(custom(function = "required_not_empty_str"))]
  pub workspace_id: String,

  #[pb(index = 2)]
  #[validate(email)]
  pub email: String,
}

#[derive(ProtoBuf, Default, Clone, Validate)]
pub struct QueryWorkspacePB {
  #[pb(index = 1)]
  #[validate(custom(function = "required_not_empty_str"))]
  pub workspace_id: String,
}

#[derive(ProtoBuf, Default, Clone, Validate)]
pub struct RemoveWorkspaceMemberPB {
  #[pb(index = 1)]
  #[validate(custom(function = "required_not_empty_str"))]
  pub workspace_id: String,

  #[pb(index = 2)]
  #[validate(email)]
  pub email: String,
}

#[derive(ProtoBuf, Default, Clone, Validate)]
pub struct UpdateWorkspaceMemberPB {
  #[pb(index = 1)]
  #[validate(custom(function = "required_not_empty_str"))]
  pub workspace_id: String,

  #[pb(index = 2)]
  #[validate(email)]
  pub email: String,

  #[pb(index = 3)]
  pub role: AFRolePB,
}

// Workspace Role
#[derive(Debug, ProtoBuf_Enum, Clone, Default, Eq, PartialEq)]
pub enum AFRolePB {
  Owner = 0,
  Member = 1,
  #[default]
  Guest = 2,
}

impl From<i32> for AFRolePB {
  fn from(value: i32) -> Self {
    match value {
      0 => AFRolePB::Owner,
      1 => AFRolePB::Member,
      2 => AFRolePB::Guest,
      _ => AFRolePB::Guest,
    }
  }
}

impl From<AFRolePB> for Role {
  fn from(value: AFRolePB) -> Self {
    match value {
      AFRolePB::Owner => Role::Owner,
      AFRolePB::Member => Role::Member,
      AFRolePB::Guest => Role::Guest,
    }
  }
}

impl From<Role> for AFRolePB {
  fn from(value: Role) -> Self {
    match value {
      Role::Owner => AFRolePB::Owner,
      Role::Member => AFRolePB::Member,
      Role::Guest => AFRolePB::Guest,
    }
  }
}

#[derive(ProtoBuf, Default, Clone, Validate)]
pub struct UserWorkspaceIdPB {
  #[pb(index = 1)]
  #[validate(custom(function = "required_not_empty_str"))]
  pub workspace_id: String,
}

#[derive(ProtoBuf, Default, Clone, Validate)]
pub struct DeleteWorkspaceIdPB {
  #[pb(index = 1)]
  #[validate(custom(function = "required_not_empty_str"))]
  pub workspace_id: String,

  #[pb(index = 2)]
  pub workspace_type: WorkspaceTypePB,
}

#[derive(ProtoBuf, Default, Clone, Validate)]
pub struct OpenUserWorkspacePB {
  #[pb(index = 1)]
  #[validate(custom(function = "required_not_empty_str"))]
  pub workspace_id: String,

  #[pb(index = 2)]
  pub workspace_type: WorkspaceTypePB,
}

#[derive(ProtoBuf, Default, Clone)]
pub struct WorkspaceMemberIdPB {
  #[pb(index = 1)]
  pub uid: i64,
}

#[derive(ProtoBuf, Default, Clone, Validate)]
pub struct CreateWorkspacePB {
  #[pb(index = 1)]
  #[validate(custom(function = "required_not_empty_str"))]
  pub name: String,

  #[pb(index = 2)]
  pub icon: String,

  #[pb(index = 3)]
  pub workspace_type: WorkspaceTypePB,
}

#[derive(ProtoBuf_Enum, Copy, Default, Debug, Clone, Eq, PartialEq)]
#[repr(u8)]
pub enum WorkspaceTypePB {
  #[default]
  LocalW = 0,
  ServerW = 1,
}

impl From<i32> for WorkspaceTypePB {
  fn from(value: i32) -> Self {
    match value {
      0 => WorkspaceTypePB::LocalW,
      1 => WorkspaceTypePB::ServerW,
      _ => WorkspaceTypePB::ServerW,
    }
  }
}

impl From<WorkspaceType> for WorkspaceTypePB {
  fn from(value: WorkspaceType) -> Self {
    match value {
      WorkspaceType::Vault => WorkspaceTypePB::LocalW,
      WorkspaceType::Cloud => WorkspaceTypePB::ServerW,
    }
  }
}

impl From<WorkspaceTypePB> for WorkspaceType {
  fn from(value: WorkspaceTypePB) -> Self {
    match value {
      WorkspaceTypePB::LocalW => WorkspaceType::Vault,
      WorkspaceTypePB::ServerW => WorkspaceType::Cloud,
    }
  }
}

#[derive(ProtoBuf_Enum, Copy, Default, Debug, Clone, Eq, PartialEq)]
#[repr(u8)]
pub enum AuthTypePB {
  #[default]
  Local = 0,
  Server = 1,
}

impl From<i32> for AuthTypePB {
  fn from(value: i32) -> Self {
    match value {
      0 => AuthTypePB::Local,
      1 => AuthTypePB::Server,
      _ => AuthTypePB::Server,
    }
  }
}

impl From<AuthProvider> for AuthTypePB {
  fn from(value: AuthProvider) -> Self {
    match value {
      AuthProvider::Local => AuthTypePB::Local,
      AuthProvider::Cloud => AuthTypePB::Server,
    }
  }
}

impl From<AuthTypePB> for AuthProvider {
  fn from(value: AuthTypePB) -> Self {
    match value {
      AuthTypePB::Local => AuthProvider::Local,
      AuthTypePB::Server => AuthProvider::Cloud,
    }
  }
}

#[derive(ProtoBuf, Default, Clone, Validate)]
pub struct RenameWorkspacePB {
  #[pb(index = 1)]
  #[validate(custom(function = "required_not_empty_str"))]
  pub workspace_id: String,

  #[pb(index = 2)]
  #[validate(custom(function = "required_not_empty_str"))]
  pub new_name: String,

  #[pb(index = 3)]
  pub workspace_type: WorkspaceTypePB,
}

#[derive(ProtoBuf, Default, Clone, Validate)]
pub struct ChangeWorkspaceIconPB {
  #[pb(index = 1)]
  #[validate(custom(function = "required_not_empty_str"))]
  pub workspace_id: String,

  #[pb(index = 2)]
  pub new_icon: String,

  #[pb(index = 3)]
  pub workspace_type: WorkspaceTypePB,
}

#[derive(Debug, ProtoBuf, Default, Clone)]
pub struct PaymentLinkPB {
  #[pb(index = 1)]
  pub payment_link: String,
}

#[derive(Debug, ProtoBuf, Default, Clone)]
pub struct WorkspaceUsagePB {
  #[pb(index = 1)]
  pub member_count: u64,
  #[pb(index = 2)]
  pub member_count_limit: u64,
  #[pb(index = 3)]
  pub storage_bytes: u64,
  #[pb(index = 4)]
  pub storage_bytes_limit: u64,
  #[pb(index = 5)]
  pub storage_bytes_unlimited: bool,
  #[pb(index = 6)]
  pub ai_responses_count: u64,
  #[pb(index = 7)]
  pub ai_responses_count_limit: u64,
  #[pb(index = 8)]
  pub ai_responses_unlimited: bool,
  #[pb(index = 9)]
  pub local_ai: bool,
}

impl From<WorkspaceUsageAndLimit> for WorkspaceUsagePB {
  fn from(workspace_usage: WorkspaceUsageAndLimit) -> Self {
    WorkspaceUsagePB {
      member_count: workspace_usage.member_count as u64,
      member_count_limit: workspace_usage.member_count_limit as u64,
      storage_bytes: workspace_usage.storage_bytes as u64,
      storage_bytes_limit: workspace_usage.storage_bytes_limit as u64,
      storage_bytes_unlimited: workspace_usage.storage_bytes_unlimited,
      ai_responses_count: workspace_usage.ai_responses_count as u64,
      ai_responses_count_limit: workspace_usage.ai_responses_count_limit as u64,
      ai_responses_unlimited: workspace_usage.ai_responses_unlimited,
      local_ai: workspace_usage.local_ai,
    }
  }
}

#[derive(Debug, ProtoBuf, Default, Clone)]
pub struct BillingPortalPB {
  #[pb(index = 1)]
  pub url: String,
}

#[derive(ProtoBuf, Default, Clone, Validate, Eq, PartialEq)]
pub struct WorkspaceSettingsPB {
  #[pb(index = 1)]
  pub disable_search_indexing: bool,

  #[pb(index = 2)]
  pub ai_model: String,

  #[pb(index = 3)]
  pub workspace_type: WorkspaceTypePB,
}

impl From<&AFWorkspaceSettings> for WorkspaceSettingsPB {
  fn from(value: &AFWorkspaceSettings) -> Self {
    Self {
      disable_search_indexing: value.disable_search_indexing,
      ai_model: value.ai_model.clone(),
      workspace_type: WorkspaceTypePB::ServerW,
    }
  }
}

#[derive(ProtoBuf, Default, Clone, Validate, Debug)]
pub struct UpdateUserWorkspaceSettingPB {
  #[pb(index = 1)]
  #[validate(custom(function = "required_not_empty_str"))]
  pub workspace_id: String,

  #[pb(index = 2, one_of)]
  pub disable_search_indexing: Option<bool>,

  #[pb(index = 3, one_of)]
  pub ai_model: Option<String>,
}

impl From<UpdateUserWorkspaceSettingPB> for AFWorkspaceSettingsChange {
  fn from(value: UpdateUserWorkspaceSettingPB) -> Self {
    let mut change = AFWorkspaceSettingsChange::new();
    if let Some(disable_search_indexing) = value.disable_search_indexing {
      change.disable_search_indexing = Some(disable_search_indexing);
    }
    if let Some(ai_model) = value.ai_model {
      change.ai_model = Some(ai_model);
    }
    change
  }
}

#[derive(ProtoBuf_Enum, Clone, Default)]
pub enum ConnectStatePB {
  #[default]
  WSDisconnected = 0,
  WSConnecting = 1,
  WSConnected = 2,
}

#[derive(ProtoBuf, Default, Clone)]
pub struct ConnectStateNotificationPB {
  #[pb(index = 1)]
  pub state: ConnectStatePB,

  #[pb(index = 2, one_of)]
  pub disconnected_reason: Option<String>,
}

impl From<ConnectState> for ConnectStateNotificationPB {
  fn from(value: ConnectState) -> Self {
    let mut disconnected_reason = None;
    let state = match value {
      ConnectState::Connected => ConnectStatePB::WSConnected,
      ConnectState::Disconnected { reason } => {
        disconnected_reason = reason.map(|v| v.to_string());
        ConnectStatePB::WSDisconnected
      },
      ConnectState::Connecting => ConnectStatePB::WSConnecting,
    };

    ConnectStateNotificationPB {
      state,
      disconnected_reason,
    }
  }
}
