use crate::cloud::UserUpdate;
use crate::entities::{AuthProvider, Role, UserProfile, UserWorkspace, WorkspaceType};
use crate::sql::{
  WorkspaceMemberTable, select_user_workspace, upsert_user_workspace, upsert_workspace_member,
};
use client_api::entity::auth_dto::{UpdateUserParams, UserMetaData};
use flowy_error::{FlowyError, FlowyResult};
use flowy_sqlite::schema::user_table;
use flowy_sqlite::{DBConnection, ExpressionMethods, RunQueryDsl, prelude::*};
use tracing::{instrument, trace};

/// The order of the fields in the struct must be the same as the order of the fields in the table.
/// Check out the [schema.rs] for table schema.
#[derive(Clone, Default, Queryable, Identifiable, Insertable)]
#[diesel(table_name = user_table)]
pub struct UserTable {
  pub(crate) id: String,
  pub(crate) name: String,
  pub(crate) icon_url: String,
  pub(crate) token: String,
  pub(crate) email: String,
  pub(crate) auth_type: i32,
  pub(crate) updated_at: i64,
  pub(crate) metadata: Option<String>,
}

#[allow(deprecated)]
impl From<(UserProfile, AuthProvider)> for UserTable {
  fn from(value: (UserProfile, AuthProvider)) -> Self {
    let (user_profile, auth_type) = value;
    let metadata = serde_json::to_string(&user_profile.metadata).ok();
    UserTable {
      id: user_profile.uid.to_string(),
      name: user_profile.name,
      #[allow(deprecated)]
      icon_url: "".to_string(),
      token: user_profile.token,
      email: user_profile.email,
      auth_type: auth_type as i32,
      updated_at: user_profile.updated_at,
      metadata,
    }
  }
}

#[derive(AsChangeset, Identifiable, Default, Debug)]
#[diesel(table_name = user_table)]
pub struct UserTableChangeset {
  pub id: String,
  pub name: Option<String>,
  pub email: Option<String>,
  pub metadata: Option<String>,
}

impl UserTableChangeset {
  pub fn new(uid: i64, params: UpdateUserParams) -> Self {
    let metadata = params.metadata.and_then(|m| serde_json::to_string(&m).ok());
    UserTableChangeset {
      id: uid.to_string(),
      name: params.name,
      email: params.email,
      metadata,
    }
  }

  pub fn from_user_profile(user_profile: UserProfile) -> Self {
    let metadata = serde_json::to_string(&user_profile.metadata).ok();
    UserTableChangeset {
      id: user_profile.uid.to_string(),
      name: Some(user_profile.name),
      email: Some(user_profile.email),
      metadata,
    }
  }
}

impl From<UserUpdate> for UserTableChangeset {
  fn from(value: UserUpdate) -> Self {
    UserTableChangeset {
      id: value.uid.to_string(),
      name: value.name,
      email: value.email,
      ..Default::default()
    }
  }
}

pub fn update_user_profile(
  conn: &mut SqliteConnection,
  mut changeset: UserTableChangeset,
) -> Result<(), FlowyError> {
  trace!("update user profile: {:?}", changeset);
  let user_id = changeset.id.clone();

  // If metadata is being updated, merge with existing metadata
  if let Some(new_metadata_str) = changeset.metadata.as_ref() {
    // Get existing user data
    if let Ok(existing_user) = select_user_table_row(user_id.parse::<i64>().unwrap_or(0), conn) {
      if let Some(existing_metadata_str) = existing_user.metadata {
        // Parse both metadata as JSON values and merge
        if let (Ok(mut existing_json), Ok(new_json)) = (
          serde_json::from_str::<serde_json::Value>(&existing_metadata_str),
          serde_json::from_str::<serde_json::Value>(new_metadata_str),
        ) {
          // Merge new metadata into existing (shallow merge of top-level keys)
          if let (Some(existing_obj), Some(new_obj)) =
            (existing_json.as_object_mut(), new_json.as_object())
          {
            for (key, value) in new_obj {
              existing_obj.insert(key.clone(), value.clone());
            }
            // Update changeset with merged metadata
            changeset.metadata = serde_json::to_string(&existing_json).ok();
          }
        }
      }
    }
  }

  update(user_table::dsl::user_table.filter(user_table::id.eq(&user_id)))
    .set(changeset)
    .execute(conn)?;
  Ok(())
}

pub fn insert_local_workspace(
  uid: i64,
  workspace_id: &str,
  workspace_name: &str,
  workspace_icon: &str,
  conn: &mut SqliteConnection,
) -> FlowyResult<UserWorkspace> {
  let user_workspace =
    UserWorkspace::new_local(workspace_id.to_string(), workspace_name, workspace_icon);
  conn.immediate_transaction(|conn| {
    let row = select_user_table_row(uid, conn)?;
    let row = WorkspaceMemberTable {
      email: row.email,
      role: Role::Owner as i32,
      name: row.name,
      avatar_url: Some(row.icon_url),
      uid,
      workspace_id: workspace_id.to_string(),
      updated_at: chrono::Utc::now().naive_utc(),
      joined_at: None,
    };

    upsert_user_workspace(uid, WorkspaceType::Vault, user_workspace.clone(), conn)?;
    upsert_workspace_member(conn, row)?;
    Ok::<_, FlowyError>(())
  })?;

  Ok(user_workspace)
}

fn select_user_table_row(uid: i64, conn: &mut SqliteConnection) -> Result<UserTable, FlowyError> {
  let row = user_table::dsl::user_table
    .filter(user_table::id.eq(&uid.to_string()))
    .first::<UserTable>(conn)
    .map_err(|err| {
      FlowyError::record_not_found().with_context(format!(
        "Can't find the user profile for user id: {}, error: {:?}",
        uid, err
      ))
    })?;
  Ok(row)
}

#[instrument(level = "debug", skip(conn), err)]
pub fn select_user_profile(
  uid: i64,
  workspace_id: &str,
  conn: &mut SqliteConnection,
) -> Result<UserProfile, FlowyError> {
  let workspace = select_user_workspace(workspace_id, conn)?;
  let workspace_type = WorkspaceType::from(workspace.workspace_type);
  let row = select_user_table_row(uid, conn)?;
  let metadata = row
    .metadata
    .as_ref()
    .and_then(|json_str| serde_json::from_str::<UserMetaData>(json_str).ok())
    .unwrap_or_default();

  let user = UserProfile {
    uid: row.id.parse::<i64>().unwrap_or(0),
    email: row.email,
    name: row.name,
    token: row.token,
    auth_type: AuthProvider::from(row.auth_type),
    workspace_type,
    updated_at: row.updated_at,
    metadata,
  };

  Ok(user)
}

pub fn select_user_auth_provider(
  uid: i64,
  conn: &mut SqliteConnection,
) -> Result<AuthProvider, FlowyError> {
  let row = select_user_table_row(uid, conn)?;
  Ok(AuthProvider::from(row.auth_type))
}

pub fn select_user_token(uid: i64, conn: &mut SqliteConnection) -> Result<String, FlowyError> {
  let row = select_user_table_row(uid, conn)?;
  Ok(row.token)
}

pub fn upsert_user(user: UserTable, mut conn: DBConnection) -> FlowyResult<()> {
  conn.immediate_transaction(|conn| {
    // delete old user if exists
    diesel::delete(user_table::dsl::user_table.filter(user_table::dsl::id.eq(&user.id)))
      .execute(conn)?;

    let _ = diesel::insert_into(user_table::table)
      .values(user)
      .execute(conn)?;
    Ok::<(), FlowyError>(())
  })?;
  Ok(())
}
