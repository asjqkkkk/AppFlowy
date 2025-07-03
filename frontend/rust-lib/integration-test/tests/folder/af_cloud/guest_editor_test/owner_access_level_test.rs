use crate::folder::af_cloud::guest_editor_test::util::{
  create_owner_and_member, create_owner_member_and_guest, AccessLevelTest,
};
use event_integration_test::user_event::use_localhost_af_cloud;
use flowy_folder::entities::*;

// owner can have full access for all public views including those created by members
// 1. owner creates a workspace and invites a member
// 2. owner creates a public space and page
// 3. member creates a public space and page
// 4. owner can update both pages (their own and member's)
#[tokio::test]
async fn owner_has_full_access_to_all_views_test() {
  use_localhost_af_cloud().await;

  let (owner, member) = create_owner_and_member().await;

  let workspace = owner
    .create_a_workspace_and_invite_member(&member, "Owner Full Access Workspace".to_string())
    .await;

  let (_owner_public_space, owner_public_page) = owner
    .create_a_public_space_and_a_page(
      &workspace,
      Some("Owner Public Space".to_string()),
      Some("Owner Public Page".to_string()),
    )
    .await;

  let (member_public_space, member_public_page) = member
    .create_a_public_space_and_a_page(
      &workspace,
      Some("Member Public Space".to_string()),
      Some("Member Public Page".to_string()),
    )
    .await;

  owner.wait_for_sync(&member_public_space.id).await;
  owner.wait_for_sync(&member_public_page.id).await;

  let update_payload = UpdateViewPayloadPB {
    view_id: owner_public_page.id.clone(),
    name: Some("Updated Owner Public Page".to_string()),
    ..Default::default()
  };
  let error = owner.update_view(update_payload).await;
  assert!(error.is_none());

  let update_payload = UpdateViewPayloadPB {
    view_id: member_public_page.id.clone(),
    name: Some("Updated Member Public Page".to_string()),
    ..Default::default()
  };
  let error = owner.update_view(update_payload).await;
  assert!(error.is_none());

  let updated_owner_page = owner.get_view(&owner_public_page.id).await.unwrap();
  assert_eq!(updated_owner_page.name, "Updated Owner Public Page");

  let updated_member_page = owner.get_view(&member_public_page.id).await.unwrap();
  assert_eq!(updated_member_page.name, "Updated Member Public Page");

  owner.delete_view(&member_public_page.id).await;

  let trash = owner.get_trash().await;
  assert!(trash
    .items
    .iter()
    .any(|item| item.id == member_public_page.id));
}

// owner can't have access the private views created by other users
//
// 1. owner create a new workspace and invite a member to the workspace
// 2. member create a private view in the workspace
// 3. owner try to access the private view
// 4. verify owner can't access the private view
#[tokio::test]
async fn owner_has_no_access_to_other_users_private_views_test() {
  use_localhost_af_cloud().await;

  let (owner, member) = create_owner_and_member().await;

  let workspace = owner
    .create_a_workspace_and_invite_member(&member, "Owner No Access Workspace".to_string())
    .await;

  let (member_private_space, member_private_page) = member
    .create_a_private_space_and_a_page(
      &workspace,
      Some("Member Private Space".to_string()),
      Some("Member Private Page".to_string()),
    )
    .await;

  tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;

  let error = owner.get_view(&member_private_space.id).await;
  assert!(error.is_err());

  let error = owner.get_view(&member_private_page.id).await;
  assert!(error.is_err());

  let member_space = member.get_view(&member_private_space.id).await.unwrap();
  assert_eq!(member_space.id, member_private_space.id);

  let member_page = member.get_view(&member_private_page.id).await.unwrap();
  assert_eq!(member_page.id, member_private_page.id);
}

// ------ Owner + Member ------

// owner can share private page with member
// 1. owner creates a workspace
// 2. owner invites a member into the workspace
// 3. owner creates a private space and a page in the private space
// 4. verify member can't access the private space and private page before sharing
// 5. owner shares the private page with the member
// 6. verify member can access the private page after sharing
#[tokio::test]
async fn owner_share_private_page_with_member_test() {
  use_localhost_af_cloud().await;

  let (owner, member) = create_owner_and_member().await;

  let workspace = owner
    .create_a_workspace_and_invite_member(&member, "Owner Workspace".to_string())
    .await;

  let (private_space, private_page) = owner
    .create_a_private_space_and_a_page(&workspace, None, None)
    .await;

  let _ = member.open_invited_workspace(&workspace.workspace_id).await;

  // member has no permission to view the private space and private page
  let error = member.get_view(&private_space.id).await;
  assert!(error.is_err());
  let error = member.get_view(&private_page.id).await;
  assert!(error.is_err());

  // owner shares the private page with the member
  owner
    .share_page_with_email(
      &private_page.id,
      &member.get_email().await,
      AFAccessLevelPB::ReadAndComment,
    )
    .await
    .unwrap();

  member.open_invited_workspace(&workspace.workspace_id).await;

  let access_level = member.preload_access_level(&private_page.id).await;
  assert_eq!(access_level, AFAccessLevelPB::ReadAndComment);

  // member has permission to view the private page
  member.wait_for_sync(&private_page.id).await;
  let member_private_page = member.get_view(&private_page.id).await.unwrap();
  assert_eq!(member_private_page.id, private_page.id);

  // member still has no permission to view the private space
  let error = member.get_view(&private_space.id).await;
  assert!(error.is_err());
}

// ------ Owner + Guest ------

// owner can share public page with guest
// 1. owner creates a workspace
// 2. owner creates a public space and a page in the public space
// 3. verify guest can't access the public space and public page before sharing
// 4. owner shares the public page with the guest
// 5. verify guest can access the public page after sharing
#[tokio::test]
async fn owner_share_public_page_with_guest_test() {
  use_localhost_af_cloud().await;

  let (owner, _, guest) = create_owner_member_and_guest().await;

  let workspace = owner.get_current_workspace().await;
  let workspace = owner.get_user_workspace(&workspace.id).await;

  let (public_space, public_page) = owner
    .create_a_public_space_and_a_page(&workspace, None, None)
    .await;

  // guest has no permission to view the public space and public page
  let error = guest.get_view(&public_space.id).await;
  assert!(error.is_err());
  let error = guest.get_view(&public_page.id).await;
  assert!(error.is_err());

  // owner shares the public page with the guest
  owner
    .share_page_with_email(
      &public_page.id,
      &guest.get_email().await,
      AFAccessLevelPB::ReadOnly,
    )
    .await
    .unwrap();

  // guest has permission to view the public page
  guest.open_invited_workspace(&workspace.workspace_id).await;

  let access_level = guest.preload_access_level(&public_page.id).await;
  assert_eq!(access_level, AFAccessLevelPB::ReadOnly);

  guest.wait_for_sync(&public_page.id).await;

  let guest_public_page = guest.get_view(&public_page.id).await.unwrap();
  assert_eq!(guest_public_page.id, public_page.id);

  // guest still has no permission to view the public space
  let error = guest.get_view(&public_space.id).await;
  assert!(error.is_err());
}

// owner can share private page with guest
// 1. owner creates a workspace
// 2. owner creates a private space and a page in the private space
// 3. verify guest can't access the private space and private page before sharing
// 4. owner shares the private page with the guest
// 5. verify guest can access the private page after sharing
#[tokio::test]
async fn owner_share_private_page_with_guest_test() {
  use_localhost_af_cloud().await;

  let (owner, _, guest) = create_owner_member_and_guest().await;

  let workspace = owner
    .create_and_open_workspace("Owner share private page with guest".to_string())
    .await;

  let (private_space, private_page) = owner
    .create_a_private_space_and_a_page(&workspace, None, None)
    .await;

  // guest has no permission to view the private space and private page
  let error = guest.get_view(&private_space.id).await;
  assert!(error.is_err());
  let error = guest.get_view(&private_page.id).await;
  assert!(error.is_err());

  // owner shares the private page with the guest
  owner
    .share_page_with_email(
      &private_page.id,
      &guest.get_email().await,
      AFAccessLevelPB::ReadAndComment,
    )
    .await
    .unwrap();

  // guest has permission to view the private page
  guest.open_invited_workspace(&workspace.workspace_id).await;

  let access_level = guest.preload_access_level(&private_page.id).await;
  assert_eq!(access_level, AFAccessLevelPB::ReadAndComment);

  guest.wait_for_sync(&private_page.id).await;

  let guest_private_page = guest.get_view(&private_page.id).await.unwrap();
  assert_eq!(guest_private_page.id, private_page.id);

  // guest still has no permission to view the private space
  let error = guest.get_view(&private_space.id).await;
  assert!(error.is_err());
}
