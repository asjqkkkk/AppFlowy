use std::{str::FromStr, time::Duration};

use anyhow::anyhow;
use event_integration_test::{retry_with_backoff, EventIntegrationTest};
use flowy_folder::entities::{AFAccessLevelPB, ViewPB};
use flowy_user::{
  entities::{RepeatedUserWorkspacePB, UserWorkspacePB},
  protobuf::UserNotification,
};
use flowy_user_pub::entities::WorkspaceType;
use tracing::debug;
use uuid::Uuid;

use crate::util::receive_with_timeout;

pub trait AccessLevelTest {
  /// A helper function to create a workspace
  async fn create_and_open_workspace(&self, workspace_name: String) -> UserWorkspacePB;

  /// A helper function to open a workspace
  async fn invite_member_to_workspace(
    &self,
    workspace: &UserWorkspacePB,
    user: &EventIntegrationTest,
  ) -> UserWorkspacePB;

  /// A helper function to create a workspace and invite a member to the workspace
  async fn create_a_workspace_and_invite_member(
    &self,
    user: &EventIntegrationTest,
    workspace_name: String,
  ) -> UserWorkspacePB;

  /// A helper function to create a public space and a page in the public space
  async fn create_a_public_space_and_a_page(
    &self,
    workspace: &UserWorkspacePB,
    space_name: Option<String>,
    page_name: Option<String>,
  ) -> (ViewPB, ViewPB);

  /// A helper function to create a private space and a page in the private space
  async fn create_a_private_space_and_a_page(
    &self,
    workspace: &UserWorkspacePB,
    space_name: Option<String>,
    page_name: Option<String>,
  ) -> (ViewPB, ViewPB);

  /// A helper function to get the invited workspace and open it (ONLY for guest)
  async fn open_invited_workspace(&self, workspace_id: &str) -> UserWorkspacePB;

  /// A helper function to preload the access level of a user
  async fn preload_access_level(&self, view_id: &str) -> AFAccessLevelPB;

  /// A helper function to get the synced workspaces
  async fn get_synced_workspaces(&self) -> Vec<UserWorkspacePB>;

  /// A helper function to get email from the user
  async fn get_email(&self) -> String;

  /// A helper function to wait for sync
  async fn wait_for_sync(&self, view_id: &str);
}

impl AccessLevelTest for EventIntegrationTest {
  async fn create_and_open_workspace(&self, workspace_name: String) -> UserWorkspacePB {
    // 1. create a workspace
    let workspace = self
      .create_workspace(&workspace_name, WorkspaceType::Cloud)
      .await;
    // 2. open the workspace

    self
      .open_workspace(&workspace.workspace_id, workspace.workspace_type)
      .await;

    workspace
  }

  async fn invite_member_to_workspace(
    &self,
    workspace: &UserWorkspacePB,
    user: &EventIntegrationTest,
  ) -> UserWorkspacePB {
    // 1. invite the member to the workspace
    self
      .add_workspace_member(&workspace.workspace_id, user)
      .await;

    // 2. get the synced workspaces
    let _ = user.get_synced_workspaces().await;

    // 3. open the workspace
    user
      .open_workspace(&workspace.workspace_id, workspace.workspace_type)
      .await;

    workspace.clone()
  }

  async fn create_a_workspace_and_invite_member(
    &self,
    user: &EventIntegrationTest,
    workspace_name: String,
  ) -> UserWorkspacePB {
    let workspace = self.create_and_open_workspace(workspace_name).await;
    self.invite_member_to_workspace(&workspace, user).await
  }

  async fn create_a_public_space_and_a_page(
    &self,
    workspace: &UserWorkspacePB,
    space_name: Option<String>,
    page_name: Option<String>,
  ) -> (ViewPB, ViewPB) {
    let current_workspace_uuid = Uuid::from_str(&workspace.workspace_id).unwrap();
    let public_space = self
      .create_public_space(
        current_workspace_uuid,
        space_name.unwrap_or("Public Space".to_string()),
      )
      .await;
    let public_page = self
      .create_view(
        &public_space.id,
        page_name.unwrap_or("Public Page".to_string()),
      )
      .await;
    (public_space, public_page)
  }

  async fn create_a_private_space_and_a_page(
    &self,
    workspace: &UserWorkspacePB,
    space_name: Option<String>,
    page_name: Option<String>,
  ) -> (ViewPB, ViewPB) {
    let current_workspace_uuid = Uuid::from_str(&workspace.workspace_id).unwrap();
    let private_space = self
      .create_private_space(
        current_workspace_uuid,
        space_name.unwrap_or("Private Space".to_string()),
      )
      .await;
    let private_page = self
      .create_view(
        &private_space.id,
        page_name.unwrap_or("Private Page".to_string()),
      )
      .await;
    (private_space, private_page)
  }

  async fn get_synced_workspaces(&self) -> Vec<UserWorkspacePB> {
    let workspaces = self.get_all_workspaces().await.items;
    let sub_id = self.get_user_profile().await.unwrap().id.to_string();
    let rx = self
      .notification_sender
      .subscribe::<RepeatedUserWorkspacePB>(
        &sub_id,
        UserNotification::DidUpdateUserWorkspaces as i32,
      );
    if let Some(result) = receive_with_timeout(rx, Duration::from_secs(10)).await {
      result.items
    } else {
      workspaces
    }
  }

  async fn open_invited_workspace(&self, workspace_id: &str) -> UserWorkspacePB {
    let synced_workspaces = self.get_synced_workspaces().await;
    let workspace = synced_workspaces
      .iter()
      .find(|w| w.workspace_id == workspace_id);
    if let Some(workspace) = workspace {
      self
        .open_workspace(workspace_id, workspace.workspace_type)
        .await;
      workspace.clone()
    } else {
      panic!("Workspace not found: {}", workspace_id);
    }
  }

  async fn preload_access_level(&self, view_id: &str) -> AFAccessLevelPB {
    let _ = self.get_shared_views().await;
    let shared_users = self.get_shared_users(view_id).await.unwrap();
    let user_email = self.get_email().await;
    if !shared_users.items.iter().any(|u| u.email == user_email) {
      panic!("User not found in shared users: {}", user_email);
    }
    self
      .get_user_access_level(view_id, &user_email)
      .await
      .unwrap()
  }

  async fn get_email(&self) -> String {
    self.get_user_profile().await.unwrap().email
  }

  async fn wait_for_sync(&self, view_id: &str) {
    retry_with_backoff(|| async {
      let result = self.get_view(view_id).await;
      if let Ok(view) = result {
        debug!("synced view: {:?}", view);
      } else {
        return Err(anyhow!("Failed to get view: {}", view_id));
      }
      Ok(())
    })
    .await
    .unwrap();
  }
}

/// A helper function create 2 clients
pub async fn create_2_clients() -> (EventIntegrationTest, EventIntegrationTest) {
  let client_1 = EventIntegrationTest::new().await;
  client_1.af_cloud_sign_up().await;
  let client_2 = EventIntegrationTest::new().await;
  client_2.af_cloud_sign_up().await;
  (client_1, client_2)
}

/// A helper function to create a owner and a member
pub async fn create_owner_and_member() -> (EventIntegrationTest, EventIntegrationTest) {
  let owner = EventIntegrationTest::new().await;
  owner.af_cloud_sign_up().await;
  let member = EventIntegrationTest::new().await;
  member.af_cloud_sign_up().await;
  (owner, member)
}

/// A helper function to create a owner, a member and a guest
pub async fn create_owner_member_and_guest() -> (
  EventIntegrationTest,
  EventIntegrationTest,
  EventIntegrationTest,
) {
  let owner = EventIntegrationTest::new().await;
  owner.af_cloud_sign_up().await;
  let member = EventIntegrationTest::new().await;
  member.af_cloud_sign_up().await;
  let guest = EventIntegrationTest::new().await;
  guest.af_cloud_sign_up().await;
  (owner, member, guest)
}
