use anyhow::Error;
use client_api::entity::{AFRole, AFUserProfile, AFWorkspaceInvitationStatus, AFWorkspaceMember};

use client_api::entity::auth_dto::UserMetaData;
use flowy_user_pub::entities::{
  AuthProvider, Role, UserProfile, WorkspaceInvitationStatus, WorkspaceMember, WorkspaceType,
};

pub fn user_profile_from_af_profile(
  token: String,
  profile: AFUserProfile,
  auth_type: AuthProvider,
) -> Result<UserProfile, Error> {
  let workspace_type = WorkspaceType::from(&auth_type);
  let metadata = profile
    .metadata
    .as_ref()
    .and_then(|json_value| serde_json::from_value::<UserMetaData>(json_value.clone()).ok())
    .unwrap_or_default();

  Ok(UserProfile {
    email: profile.email.unwrap_or("".to_string()),
    name: profile.name.unwrap_or("".to_string()),
    token,
    auth_type: AuthProvider::Cloud,
    uid: profile.uid,
    updated_at: profile.updated_at,
    workspace_type,
    metadata,
  })
}

pub fn to_af_role(role: Role) -> AFRole {
  match role {
    Role::Owner => AFRole::Owner,
    Role::Member => AFRole::Member,
    Role::Guest => AFRole::Guest,
  }
}

pub fn from_af_role(role: AFRole) -> Role {
  match role {
    AFRole::Owner => Role::Owner,
    AFRole::Member => Role::Member,
    AFRole::Guest => Role::Guest,
  }
}

pub fn from_af_workspace_member(member: AFWorkspaceMember) -> WorkspaceMember {
  WorkspaceMember {
    email: member.email,
    role: from_af_role(member.role),
    name: member.name,
    avatar_url: member.avatar_url,
    joined_at: member.joined_at.map(|dt| dt.timestamp()),
  }
}

pub fn to_workspace_invitation_status(
  status: WorkspaceInvitationStatus,
) -> AFWorkspaceInvitationStatus {
  match status {
    WorkspaceInvitationStatus::Pending => AFWorkspaceInvitationStatus::Pending,
    WorkspaceInvitationStatus::Accepted => AFWorkspaceInvitationStatus::Accepted,
    WorkspaceInvitationStatus::Rejected => AFWorkspaceInvitationStatus::Rejected,
  }
}

pub fn from_af_workspace_invitation_status(
  status: AFWorkspaceInvitationStatus,
) -> WorkspaceInvitationStatus {
  match status {
    AFWorkspaceInvitationStatus::Pending => WorkspaceInvitationStatus::Pending,
    AFWorkspaceInvitationStatus::Accepted => WorkspaceInvitationStatus::Accepted,
    AFWorkspaceInvitationStatus::Rejected => WorkspaceInvitationStatus::Rejected,
  }
}
