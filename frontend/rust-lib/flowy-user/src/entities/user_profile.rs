use super::{AFRolePB, WorkspaceTypePB};
use crate::entities::parser::{UserEmail, UserIcon, UserName};
use crate::entities::AuthTypePB;
use crate::errors::ErrorCode;
use client_api::entity::auth_dto::{MetadataKey, UpdateUserParams};
use flowy_derive::{ProtoBuf, ProtoBuf_Enum};
use flowy_user_pub::entities::*;
use flowy_user_pub::sql::UserWorkspaceTable;
use lib_infra::validator_fn::required_not_empty_str;
use std::convert::TryInto;
use validator::Validate;

#[derive(Default, ProtoBuf)]
pub struct UserTokenPB {
  #[pb(index = 1)]
  pub token: String,
}

#[derive(ProtoBuf, Default, Clone)]
pub struct UserSettingPB {
  #[pb(index = 1)]
  pub(crate) user_folder: String,
}

#[derive(ProtoBuf, Default, Eq, PartialEq, Debug, Clone)]
pub struct UserProfilePB {
  #[pb(index = 1)]
  pub id: i64,

  #[pb(index = 2)]
  pub email: String,

  #[pb(index = 3)]
  pub name: String,

  #[pb(index = 4)]
  pub token: String,

  #[pb(index = 5)]
  pub icon_url: String,

  #[pb(index = 6)]
  pub user_auth_type: AuthTypePB,

  #[pb(index = 7)]
  pub workspace_type: WorkspaceTypePB,
}

#[derive(ProtoBuf_Enum, Eq, PartialEq, Debug, Clone)]
pub enum EncryptionTypePB {
  NoEncryption = 0,
  Symmetric = 1,
}

impl Default for EncryptionTypePB {
  fn default() -> Self {
    Self::NoEncryption
  }
}

impl From<UserProfile> for UserProfilePB {
  fn from(user_profile: UserProfile) -> Self {
    Self {
      id: user_profile.uid,
      email: user_profile.email,
      name: user_profile.name,
      token: user_profile.token,
      icon_url: user_profile
        .metadata
        .get_typed(MetadataKey::IconUrl)
        .unwrap_or_default(),
      user_auth_type: user_profile.auth_type.into(),
      workspace_type: user_profile.workspace_type.into(),
    }
  }
}

#[derive(ProtoBuf, Default)]
pub struct UpdateUserProfilePayloadPB {
  #[pb(index = 1)]
  pub id: i64,

  #[pb(index = 2, one_of)]
  pub name: Option<String>,

  #[pb(index = 3, one_of)]
  pub email: Option<String>,

  #[pb(index = 4, one_of)]
  pub password: Option<String>,

  #[pb(index = 5, one_of)]
  pub icon_url: Option<String>,
}

impl UpdateUserProfilePayloadPB {
  pub fn new(id: i64) -> Self {
    Self {
      id,
      ..Default::default()
    }
  }

  pub fn name(mut self, name: &str) -> Self {
    self.name = Some(name.to_owned());
    self
  }

  pub fn email(mut self, email: &str) -> Self {
    self.email = Some(email.to_owned());
    self
  }

  pub fn password(mut self, password: &str) -> Self {
    self.password = Some(password.to_owned());
    self
  }

  pub fn icon_url(mut self, icon_url: &str) -> Self {
    self.icon_url = Some(icon_url.to_owned());
    self
  }
}

impl TryInto<UpdateUserParams> for UpdateUserProfilePayloadPB {
  type Error = ErrorCode;

  fn try_into(self) -> Result<UpdateUserParams, Self::Error> {
    let mut params = UpdateUserParams::new();
    params = match self.name {
      None => params,
      Some(name) => params.with_name(UserName::parse(name)?.0),
    };

    params = match self.email {
      None => params,
      Some(email) => params.with_email(UserEmail::parse(email)?.0),
    };

    params = match self.password {
      None => params,
      Some(password) => params.with_password(password),
    };

    params = match self.icon_url {
      None => params,
      Some(icon_url) => {
        params.with_metadata_key(MetadataKey::IconUrl, UserIcon::parse(icon_url)?.0)
      },
    };

    Ok(params)
  }
}

#[derive(ProtoBuf, Default, Debug, Clone)]
pub struct RepeatedUserWorkspacePB {
  #[pb(index = 1)]
  pub items: Vec<UserWorkspacePB>,
}

impl From<Vec<UserWorkspace>> for RepeatedUserWorkspacePB {
  fn from(workspaces: Vec<UserWorkspace>) -> Self {
    Self {
      items: workspaces.into_iter().map(UserWorkspacePB::from).collect(),
    }
  }
}

#[derive(ProtoBuf, Default, Debug, Clone, Validate)]
pub struct UserWorkspacePB {
  #[pb(index = 1)]
  #[validate(custom(function = "required_not_empty_str"))]
  pub workspace_id: String,

  #[pb(index = 2)]
  pub name: String,

  #[pb(index = 3)]
  pub created_at_timestamp: i64,

  #[pb(index = 4)]
  pub icon: String,

  #[pb(index = 5)]
  pub member_count: i64,

  #[pb(index = 6, one_of)]
  pub role: Option<AFRolePB>,

  #[pb(index = 7)]
  pub workspace_type: WorkspaceTypePB,
}

impl From<UserWorkspace> for UserWorkspacePB {
  fn from(workspace: UserWorkspace) -> Self {
    Self {
      workspace_id: workspace.id,
      name: workspace.name,
      created_at_timestamp: workspace.created_at.timestamp(),
      icon: workspace.icon,
      member_count: workspace.member_count,
      role: workspace.role.map(AFRolePB::from),
      workspace_type: WorkspaceTypePB::from(workspace.workspace_type),
    }
  }
}

impl From<UserWorkspaceTable> for UserWorkspacePB {
  fn from(value: UserWorkspaceTable) -> Self {
    Self {
      workspace_id: value.id,
      name: value.name,
      created_at_timestamp: value.created_at,
      icon: value.icon,
      member_count: value.member_count,
      role: value.role.map(AFRolePB::from),
      workspace_type: WorkspaceTypePB::from(value.workspace_type),
    }
  }
}

#[derive(ProtoBuf, Default, Clone)]
pub struct ResetWorkspacePB {
  #[pb(index = 1)]
  pub uid: i64,

  #[pb(index = 2)]
  pub workspace_id: String,
}
