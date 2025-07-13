use crate::migrations::session_migration::migrate_session;
use crate::services::db::UserDB;
use crate::services::entities::{UserConfig, UserPaths};

use crate::entities::PersonalSubscriptionInfoPB;
use arc_swap::ArcSwapOption;
use client_api::v2::CollabKVActionExt;
use collab::core::collab::default_client_id;
use collab::preclude::ClientID;
use collab_plugins::local_storage::kv::doc::CollabKVAction;
use collab_plugins::local_storage::kv::KVTransactionDB;
use collab_plugins::CollabKVDB;
use flowy_error::{internal_error, ErrorCode, FlowyError, FlowyResult};
use flowy_sqlite::kv::KVStorePreferences;
use flowy_sqlite::DBConnection;
use flowy_user_pub::entities::{AuthProvider, CheckVaultResult, UserWorkspace, WorkspaceType};
use flowy_user_pub::session::Session;
use flowy_user_pub::sql::{
  select_user_auth_provider, select_user_workspace, select_user_workspace_type,
};
use std::path::PathBuf;
use std::str::FromStr;
use std::sync::atomic::{AtomicI64, Ordering};
use std::sync::{Arc, Weak};
use tracing::{debug, error, info};
use uuid::Uuid;

const PERSONAL_SUBSCRIPTION_KEY: &str = "personal_subscription_v1";

pub struct AuthenticateUser {
  pub user_config: UserConfig,
  pub(crate) database: Arc<UserDB>,
  pub(crate) user_paths: UserPaths,
  store_preferences: Arc<KVStorePreferences>,
  session: ArcSwapOption<Session>,
  refresh_user_profile_since: AtomicI64,
}

impl Drop for AuthenticateUser {
  fn drop(&mut self) {
    tracing::trace!(
      "[Drop ]Drop AuthenticateUser: {:?}",
      self.session.load_full().map(|s| s.user_id)
    );
  }
}

impl AuthenticateUser {
  pub fn new(user_config: UserConfig, store_preferences: Arc<KVStorePreferences>) -> Self {
    let user_paths = UserPaths::new(user_config.storage_path.clone());
    let database = Arc::new(UserDB::new(user_paths.clone()));
    let session = migrate_session(&user_config.session_cache_key, &store_preferences).map(Arc::new);
    let refresh_user_profile_since = AtomicI64::new(0);
    Self {
      user_config,
      database,
      user_paths,
      store_preferences,
      session: ArcSwapOption::from(session),
      refresh_user_profile_since,
    }
  }

  pub fn should_load_user_profile(&self) -> bool {
    let now = chrono::Utc::now().timestamp();
    if now - self.refresh_user_profile_since.load(Ordering::SeqCst) < 5 {
      return false;
    }
    self.refresh_user_profile_since.store(now, Ordering::SeqCst);
    true
  }

  pub fn user_id(&self) -> FlowyResult<i64> {
    let session = self.get_session()?;
    Ok(session.user_id)
  }

  pub(crate) fn cache_personal_subscription(
    &self,
    subscription: &PersonalSubscriptionInfoPB,
  ) -> FlowyResult<()> {
    if subscription.subscriptions.is_empty() {
      self.store_preferences.remove(PERSONAL_SUBSCRIPTION_KEY);
    } else {
      debug!("Caching personal subscription info: {:?}", subscription);
      if let Err(err) = self
        .store_preferences
        .set_object(PERSONAL_SUBSCRIPTION_KEY, subscription)
      {
        error!("Failed to store personal subscription info: {}", err);
      }
    }
    Ok(())
  }

  pub(crate) fn remove_cached_personal_subscription(&self) {
    debug!("Caching personal subscription info");
    self.store_preferences.remove(PERSONAL_SUBSCRIPTION_KEY)
  }

  pub(crate) fn get_cached_personal_subscription(&self) -> Option<PersonalSubscriptionInfoPB> {
    self.store_preferences.get_object(PERSONAL_SUBSCRIPTION_KEY)
  }

  pub async fn validate_vault(&self) -> FlowyResult<CheckVaultResult> {
    let session = self.get_session()?;
    let mut conn = self.get_sqlite_connection(session.user_id)?;
    let auth_provider = select_user_auth_provider(session.user_id, &mut conn)?;
    let workspace_type = select_user_workspace_type(&session.workspace_id, &mut conn)?;

    let is_vault = matches!(workspace_type, WorkspaceType::Vault)
      && matches!(auth_provider, AuthProvider::Cloud);

    let is_vault_enabled = if cfg!(debug_assertions) {
      // In debug mode, we assume vault is enabled for testing purposes
      true
    } else {
      match self.get_cached_personal_subscription() {
        None => false,
        Some(info) => info
          .subscriptions
          .iter()
          .any(|subscription| subscription.is_vault_active()),
      }
    };

    Ok(CheckVaultResult {
      is_vault,
      is_vault_enabled,
    })
  }

  pub async fn is_anon(&self) -> FlowyResult<bool> {
    let uid = self.user_id()?;
    let mut conn = self.get_sqlite_connection(uid)?;
    let auth_provider = select_user_auth_provider(uid, &mut conn)?;
    Ok(matches!(auth_provider, AuthProvider::Local))
  }

  pub fn device_id(&self) -> FlowyResult<String> {
    Ok(self.user_config.device_id.to_string())
  }

  pub fn collab_client_id(&self, workspace_id: &Uuid) -> ClientID {
    let get_client_id = || {
      let uid = self.user_id()?;
      let db = self
        .get_collab_db(uid)?
        .upgrade()
        .ok_or_else(|| FlowyError::internal().with_context("Unexpected error: CollabDB is None"))?;

      let client_id = db.read_txn().client_id(workspace_id)?;
      Ok::<_, FlowyError>(client_id)
    };

    get_client_id().unwrap_or_else(|_| default_client_id())
  }

  pub fn workspace_id(&self) -> FlowyResult<Uuid> {
    let session = self.get_session()?;
    let workspace_uuid = Uuid::from_str(&session.workspace_id)?;
    Ok(workspace_uuid)
  }

  pub fn get_current_workspace_type(&self) -> FlowyResult<WorkspaceType> {
    let session = self.get_session()?;
    let mut conn = self.get_sqlite_connection(session.user_id)?;
    let workspace_type = select_user_workspace_type(&session.workspace_id, &mut conn)?;
    Ok(workspace_type)
  }

  pub fn get_workspace_type(&self, workspace_id: &Uuid) -> Result<WorkspaceType, FlowyError> {
    let uid = self.user_id()?;
    let mut conn = self.get_sqlite_connection(uid)?;
    select_user_workspace_type(&workspace_id.to_string(), &mut conn)
  }

  pub fn workspace_database_object_id(&self) -> FlowyResult<Uuid> {
    let session = self.get_session()?;
    let mut conn = self.get_sqlite_connection(session.user_id)?;
    let workspace = select_user_workspace(&session.workspace_id, &mut conn)?;
    let id = Uuid::from_str(&workspace.database_storage_id)?;
    Ok(id)
  }

  pub fn get_current_user_collab_db(&self) -> FlowyResult<Weak<CollabKVDB>> {
    let session = self.get_session()?;
    self.database.get_weak_collab_db(session.user_id)
  }

  pub fn get_collab_db(&self, uid: i64) -> FlowyResult<Weak<CollabKVDB>> {
    self.database.get_weak_collab_db(uid)
  }

  pub fn get_sqlite_connection(&self, uid: i64) -> FlowyResult<DBConnection> {
    self.database.get_connection(uid)
  }

  pub fn get_index_path(&self) -> FlowyResult<PathBuf> {
    let uid = self.user_id()?;
    Ok(self.user_paths.tanvity_index_path(uid))
  }

  pub fn get_user_data_dir(&self) -> FlowyResult<PathBuf> {
    let uid = self.user_id()?;
    Ok(PathBuf::from(self.user_paths.user_data_dir(uid)))
  }

  pub fn get_application_root_dir(&self) -> &str {
    self.user_paths.root()
  }

  pub fn close_db(&self) -> FlowyResult<()> {
    let session = self.get_session()?;
    info!("Close db for user: {}", session.user_id);
    self.database.close(session.user_id)?;
    Ok(())
  }

  pub fn is_collab_on_disk(&self, uid: i64, object_id: &str) -> FlowyResult<bool> {
    let session = self.get_session()?;
    let collab_db = self
      .database
      .get_weak_collab_db(uid)?
      .upgrade()
      .ok_or_else(|| FlowyError::internal().with_context("Collab db is not initialized"))?;
    let read_txn = collab_db.read_txn();
    Ok(read_txn.is_exist(uid, session.workspace_id.as_str(), object_id))
  }

  pub fn set_session(&self, session: Option<Arc<Session>>) -> Result<(), FlowyError> {
    match session {
      None => {
        let previous = self.session.swap(session);
        info!("remove session: {:?}", previous);
        self
          .store_preferences
          .remove(self.user_config.session_cache_key.as_ref());
      },
      Some(session) => {
        self.session.swap(Some(session.clone()));
        info!("Set current session: {:?}", session);
        self
          .store_preferences
          .set_object(&self.user_config.session_cache_key, &session)
          .map_err(internal_error)?;
      },
    }
    Ok(())
  }

  pub fn set_user_workspace(&self, user_workspace: UserWorkspace) -> FlowyResult<()> {
    let session = self.get_session()?;
    self.set_session(Some(Arc::new(Session {
      user_id: session.user_id,
      user_uuid: session.user_uuid,
      workspace_id: user_workspace.id,
    })))
  }

  pub fn get_session(&self) -> FlowyResult<Arc<Session>> {
    if let Some(session) = self.session.load_full() {
      return Ok(session);
    }

    match self
      .store_preferences
      .get_object::<Session>(&self.user_config.session_cache_key)
    {
      None => Err(FlowyError::new(
        ErrorCode::RecordNotFound,
        "Can't find user session. Please login again",
      )),
      Some(session) => {
        info!("Get session from preferences: {:?}", session);
        let session = Arc::new(session);
        self.session.store(Some(session.clone()));
        Ok(session)
      },
    }
  }

  pub fn get_active_user_workspace(&self) -> FlowyResult<UserWorkspace> {
    let session = self.get_session()?;
    let mut conn = self.get_sqlite_connection(session.user_id)?;
    let workspace = select_user_workspace(&session.workspace_id, &mut conn)?;
    Ok(workspace.into())
  }
}
