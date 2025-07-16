use crate::entities::{
  AuthProvider, AuthResponse, Role, UpdateUserProfileParams, UserProfile, UserTokenState,
  UserWorkspace, WorkspaceInvitation, WorkspaceInvitationStatus, WorkspaceMember, WorkspaceType,
};
use client_api::entity::GotrueTokenResponse;
use client_api::entity::billing_dto::SubscriptionPlanDetail;
pub use client_api::entity::billing_dto::SubscriptionStatus;
use client_api::entity::billing_dto::WorkspaceSubscriptionStatus;
use client_api::entity::billing_dto::WorkspaceUsageAndLimit;
use client_api::entity::billing_dto::{PersonalPlan, RecurringInterval};
use client_api::entity::billing_dto::{PersonalSubscriptionStatus, SubscriptionPlan};
pub use client_api::entity::{AFWorkspaceSettings, AFWorkspaceSettingsChange};
use collab::preclude::ClientID;
use collab_entity::CollabType;
use flowy_ai_pub::cloud::WorkspaceNotification;
use flowy_error::{ErrorCode, FlowyError, FlowyResult, internal_error};
use lib_infra::async_trait::async_trait;
use lib_infra::box_any::BoxAny;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;
use std::fmt::{Display, Formatter};
use std::str::FromStr;
use std::sync::Arc;
use tokio::sync::broadcast::Receiver;
use tokio_stream::wrappers::WatchStream;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserCloudConfig {
  pub enable_sync: bool,
  pub enable_encrypt: bool,
  // The secret used to encrypt the user's data
  pub encrypt_secret: String,
}

impl UserCloudConfig {
  pub fn new(encrypt_secret: String) -> Self {
    Self {
      enable_sync: true,
      enable_encrypt: false,
      encrypt_secret,
    }
  }

  pub fn with_enable_encrypt(mut self, enable_encrypt: bool) -> Self {
    self.enable_encrypt = enable_encrypt;
    // When the enable_encrypt is true, the encrypt_secret should not be empty
    debug_assert!(!self.encrypt_secret.is_empty());
    self
  }
}

impl Display for UserCloudConfig {
  fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
    write!(
      f,
      "enable_sync: {}, enable_encrypt: {}",
      self.enable_sync, self.enable_encrypt
    )
  }
}
#[async_trait]
pub trait UserServerProvider: Send + Sync {
  fn set_token(&self, token: Option<String>) -> Result<(), FlowyError>;
  fn get_access_token(&self) -> Option<String>;
  fn notify_access_token_invalid(&self);
  fn set_ai_model(&self, ai_model: &str) -> Result<(), FlowyError>;
  fn subscribe_token_state(&self) -> Option<WatchStream<UserTokenState>>;
  fn set_enable_sync(&self, uid: i64, enable_sync: bool);
  fn set_auth_provider(&self, auth_type: &AuthProvider) -> Result<(), FlowyError>;
  fn set_network_reachable(&self, reachable: bool);
  fn set_encrypt_secret(&self, secret: String);
  fn current_workspace_service(&self) -> Result<Arc<dyn UserWorkspaceService>, FlowyError>;
  fn workspace_service(
    &self,
    workspace_type: WorkspaceType,
  ) -> Result<Arc<dyn UserWorkspaceService>, FlowyError>;
  fn auth_service(&self) -> Result<Arc<dyn UserAuthService>, FlowyError>;
  fn user_profile_service(&self) -> Result<Arc<dyn UserProfileService>, FlowyError>;
  fn billing_service(&self) -> Result<Arc<dyn UserBillingService>, FlowyError>;
  fn collab_service(&self) -> Result<Arc<dyn UserCollabService>, FlowyError>;
  fn service_url(&self) -> String;
  fn ws_url(&self) -> String;

  async fn create_workspace(
    &self,
    workspace_name: &str,
    workspace_icon: &str,
    workspace_type: WorkspaceType,
  ) -> FlowyResult<UserWorkspace>;
}

/// Provide the generic interface for the user cloud service
/// The user cloud service is responsible for the user authentication and user profile management
#[allow(unused_variables)]
#[async_trait]
pub trait UserWorkspaceService: Send + Sync + 'static {
  async fn open_workspace(&self, workspace_id: &Uuid) -> Result<UserWorkspace, FlowyError>;

  /// Return the all the workspaces of the user
  async fn get_all_workspace(&self, uid: i64) -> Result<Vec<UserWorkspace>, FlowyError>;

  /// Creates a new workspace for the user.
  /// Returns the new workspace if successful
  async fn create_workspace(
    &self,
    workspace_name: &str,
    workspace_icon: &str,
  ) -> Result<UserWorkspace, FlowyError>;

  // Updates the workspace name and icon
  async fn patch_workspace(
    &self,
    workspace_id: &Uuid,
    new_workspace_name: Option<String>,
    new_workspace_icon: Option<String>,
  ) -> Result<(), FlowyError>;

  /// Deletes a workspace owned by the user.
  async fn delete_workspace(&self, workspace_id: &Uuid) -> Result<(), FlowyError>;

  async fn invite_workspace_member(
    &self,
    invitee_email: String,
    workspace_id: Uuid,
    role: Role,
  ) -> Result<(), FlowyError> {
    Ok(())
  }

  async fn list_workspace_invitations(
    &self,
    filter: Option<WorkspaceInvitationStatus>,
  ) -> Result<Vec<WorkspaceInvitation>, FlowyError> {
    Ok(vec![])
  }

  async fn accept_workspace_invitations(&self, invite_id: String) -> Result<(), FlowyError> {
    Ok(())
  }

  async fn remove_workspace_member(
    &self,
    user_email: String,
    workspace_id: Uuid,
  ) -> Result<(), FlowyError> {
    Ok(())
  }

  async fn update_workspace_member(
    &self,
    user_email: String,
    workspace_id: Uuid,
    role: Role,
  ) -> Result<(), FlowyError> {
    Ok(())
  }

  async fn get_workspace_members(
    &self,
    workspace_id: Uuid,
  ) -> Result<Vec<WorkspaceMember>, FlowyError>;

  fn receive_realtime_event(&self, _json: Value) {}

  async fn leave_workspace(&self, workspace_id: &Uuid) -> Result<(), FlowyError> {
    Ok(())
  }

  async fn get_workspace_member(
    &self,
    workspace_id: &Uuid,
    uid: i64,
  ) -> Result<WorkspaceMember, FlowyError>;
  async fn get_workspace_setting(
    &self,
    workspace_id: &Uuid,
  ) -> Result<AFWorkspaceSettings, FlowyError>;

  async fn update_workspace_setting(
    &self,
    workspace_id: &Uuid,
    workspace_settings: AFWorkspaceSettingsChange,
  ) -> Result<AFWorkspaceSettings, FlowyError>;
}

#[allow(unused_variables)]
#[async_trait]
pub trait UserCollabService: Send + Sync + 'static {
  async fn get_user_awareness_doc_state(
    &self,
    uid: i64,
    workspace_id: &Uuid,
    object_id: &Uuid,
    client_id: ClientID,
  ) -> Result<Vec<u8>, FlowyError>;

  async fn batch_create_collab_object(
    &self,
    workspace_id: &Uuid,
    objects: Vec<UserCollabParams>,
  ) -> Result<(), FlowyError>;
}

/// Provide the generic interface for the user cloud service
/// The user cloud service is responsible for the user authentication and user profile management
#[allow(unused_variables)]
#[async_trait]
pub trait UserBillingService: Send + Sync + 'static {
  async fn subscribe_workspace(
    &self,
    workspace_id: Uuid,
    recurring_interval: RecurringInterval,
    workspace_subscription_plan: SubscriptionPlan,
    success_url: String,
  ) -> Result<String, FlowyError> {
    Err(FlowyError::not_support())
  }

  async fn subscribe_personal(
    &self,
    recurring_interval: RecurringInterval,
    subscription_plan: PersonalPlan,
    success_url: String,
  ) -> Result<String, FlowyError> {
    Err(FlowyError::not_support())
  }

  /// Get the workspace subscriptions for a workspace
  async fn get_workspace_subscriptions(
    &self,
    workspace_id: &Uuid,
  ) -> Result<Vec<WorkspaceSubscriptionStatus>, FlowyError>;
  async fn cancel_workspace_subscription(
    &self,
    workspace_id: String,
    plan: SubscriptionPlan,
    reason: Option<String>,
  ) -> Result<(), FlowyError>;

  async fn cancel_personal_subscription(
    &self,
    plan: PersonalPlan,
    reason: Option<String>,
  ) -> Result<(), FlowyError>;

  async fn get_personal_subscription_status(
    &self,
  ) -> Result<Vec<PersonalSubscriptionStatus>, FlowyError>;

  async fn get_workspace_plan(
    &self,
    workspace_id: Uuid,
  ) -> Result<Vec<SubscriptionPlan>, FlowyError>;

  async fn get_workspace_usage(
    &self,
    workspace_id: &Uuid,
  ) -> Result<WorkspaceUsageAndLimit, FlowyError>;

  async fn billing_portal_url(&self) -> Result<String, FlowyError>;

  async fn update_workspace_subscription_payment_period(
    &self,
    workspace_id: &Uuid,
    plan: SubscriptionPlan,
    recurring_interval: RecurringInterval,
  ) -> Result<(), FlowyError> {
    Ok(())
  }

  async fn get_subscription_plan_details(&self) -> Result<Vec<SubscriptionPlanDetail>, FlowyError> {
    Ok(vec![])
  }
}

/// Provide the generic interface for the user cloud service
/// The user cloud service is responsible for the user authentication and user profile management
#[allow(unused_variables)]
#[async_trait]
pub trait UserAuthService: Send + Sync + 'static {
  /// Sign up a new account.
  /// The type of the params is defined the this trait's implementation.
  /// Use the `unbox_or_error` of the [BoxAny] to get the params.
  async fn sign_up(&self, params: BoxAny) -> Result<AuthResponse, FlowyError>;

  /// Sign in an account
  /// The type of the params is defined the this trait's implementation.
  async fn sign_in(&self, params: BoxAny) -> Result<AuthResponse, FlowyError>;

  /// Sign out an account
  async fn sign_out(&self, token: Option<String>) -> Result<(), FlowyError>;

  /// Delete an account and all the data associated with the account
  async fn delete_account(&self) -> Result<(), FlowyError>;
  /// Generate a sign in url for the user with the given email
  /// Currently, only use the admin client for testing
  async fn generate_sign_in_url_with_email(&self, email: &str) -> Result<String, FlowyError>;

  async fn create_user(&self, email: &str, password: &str) -> Result<(), FlowyError>;

  async fn sign_in_with_password(
    &self,
    email: &str,
    password: &str,
  ) -> Result<GotrueTokenResponse, FlowyError>;

  async fn sign_in_with_magic_link(&self, email: &str, redirect_to: &str)
  -> Result<(), FlowyError>;

  async fn sign_in_with_passcode(
    &self,
    email: &str,
    passcode: &str,
  ) -> Result<GotrueTokenResponse, FlowyError>;

  /// When the user opens the OAuth URL, it redirects to the corresponding provider's OAuth web page.
  /// After the user is authenticated, the browser will open a deep link to the AppFlowy app (iOS, macOS, etc.),
  /// which will call [Client::sign_in_with_url]generate_sign_in_url_with_email to sign in.
  ///
  /// For example, the OAuth URL on Google looks like `https://appflowy.io/authorize?provider=google`.
  async fn generate_oauth_url_with_provider(&self, provider: &str) -> Result<String, FlowyError>;
}

#[async_trait]
pub trait UserProfileService: Send + Sync + 'static {
  /// Using the user's token to update the user information
  async fn update_user(&self, params: UpdateUserProfileParams) -> Result<(), FlowyError>;

  /// Get the user information using the user's token or uid
  /// return None if the user is not found
  async fn get_user_profile(&self, uid: i64, workspace_id: &str)
  -> Result<UserProfile, FlowyError>;
}

pub type UserUpdateReceiver = Receiver<WorkspaceNotification>;
#[derive(Debug, Clone)]
pub struct UserUpdate {
  pub uid: i64,
  pub name: Option<String>,
  pub email: Option<String>,
  pub encryption_sign: String,
}

pub fn uuid_from_map(map: &HashMap<String, String>) -> Result<Uuid, FlowyError> {
  let uuid = map
    .get("uuid")
    .ok_or_else(|| FlowyError::new(ErrorCode::MissingAuthField, "Missing uuid field"))?
    .as_str();
  Uuid::from_str(uuid).map_err(internal_error)
}

#[derive(Debug)]
pub struct UserCollabParams {
  pub object_id: String,
  pub encoded_collab: Vec<u8>,
  pub collab_type: CollabType,
}
