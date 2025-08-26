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

  #[pb(index = 8)]
  pub date_format: i32,

  #[pb(index = 9)]
  pub time_format: i32,

  #[pb(index = 10)]
  pub start_week_on: i32,

  #[pb(index = 11)]
  pub language: String,
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
      date_format: user_profile
        .metadata
        .get_typed(MetadataKey::DateFormat)
        .unwrap_or(3),
      time_format: user_profile
        .metadata
        .get_typed(MetadataKey::Custom(USER_METADATA_TIME_FORMAT.to_owned()))
        .unwrap_or(1),
      start_week_on: user_profile
        .metadata
        .get_typed(MetadataKey::Custom(USER_METADATA_START_WEEK_ON.to_owned()))
        .unwrap_or_default(),
      language: user_profile
        .metadata
        .get_typed(MetadataKey::Language)
        .unwrap_or_default(),
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

  #[pb(index = 6, one_of)]
  pub date_format: Option<i32>,

  #[pb(index = 7, one_of)]
  pub time_format: Option<i32>,

  #[pb(index = 8, one_of)]
  pub start_week_on: Option<i32>,

  #[pb(index = 9, one_of)]
  pub language: Option<String>,
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

    if let Some(name) = self.name {
      params = params.with_name(UserName::parse(name)?.0);
    }
    if let Some(email) = self.email {
      params = params.with_email(UserEmail::parse(email)?.0);
    }
    if let Some(password) = self.password {
      params = params.with_password(password);
    }
    if let Some(icon_url) = self.icon_url {
      params = params.with_metadata_key(MetadataKey::IconUrl, UserIcon::parse(icon_url)?.0);
    }
    if let Some(date_format) = self.date_format {
      params = params.with_metadata_key(
        MetadataKey::Custom(USER_METADATA_DATE_FORMAT.to_string()),
        date_format,
      );
    }
    if let Some(time_format) = self.time_format {
      params = params.with_metadata_key(
        MetadataKey::Custom(USER_METADATA_TIME_FORMAT.to_string()),
        time_format,
      );
    }
    if let Some(start_week_on) = self.start_week_on {
      params = params.with_metadata_key(
        MetadataKey::Custom(USER_METADATA_START_WEEK_ON.to_string()),
        start_week_on,
      );
    }
    if let Some(language) = self.language {
      params = params.with_metadata_key(MetadataKey::Language, language);
    }

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
