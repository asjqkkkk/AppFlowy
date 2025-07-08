use crate::folder::af_cloud::guest_editor_test::util::{
  create_owner_and_member, create_owner_member_and_guest, AccessLevelTest,
};
use event_integration_test::user_event::use_localhost_af_cloud;
use flowy_folder::entities::AFAccessLevelPB;

// ------ Member + Owner ------

// 1. owner creates a workspace
// 2. owner invites the member into the workspace
// 2. owner creates a public space and a page in the public space
// 3. owner creates a private space and a page in the private space
// 5. verify member can access public spaces but not the private space
#[tokio::test]
async fn member_has_access_to_public_views_test() {
  use_localhost_af_cloud().await;

  let (owner, member) = create_owner_and_member().await;

  let workspace = owner
    .create_a_workspace_and_invite_member(&member, "Member Workspace".to_string())
    .await;

  let (public_space, public_page) = owner
    .create_a_public_space_and_a_page(&workspace, None, None)
    .await;
  let (private_space, private_page) = owner
    .create_a_private_space_and_a_page(&workspace, None, None)
    .await;

  let _ = member.open_invited_workspace(&workspace.workspace_id).await;

  // member has permission to view the public space and public page
  let member_public_space = member.get_view(&public_space.id).await.unwrap();
  assert_eq!(member_public_space.id, public_space.id);
  let member_public_page = member.get_view(&public_page.id).await.unwrap();
  assert_eq!(member_public_page.id, public_page.id);

  // member has no permission to view the private space and private page
  let error = member.get_view(&private_space.id).await;
  assert!(error.is_err());
  let error = member.get_view(&private_page.id).await;
  assert!(error.is_err());
}

// 1. owner creates a workspace
// 2. owner invites the member into the workspace
// 3. member creates a private space and a page in the private space
// 4. verify member can access the private space and private page
// 5. owner can't access the private space and private page
#[tokio::test]
async fn member_has_access_to_own_private_views_test() {
  use_localhost_af_cloud().await;

  let (owner, member) = create_owner_and_member().await;

  let workspace = owner
    .create_a_workspace_and_invite_member(&member, "Member Workspace".to_string())
    .await;

  let (private_space, private_page) = member
    .create_a_private_space_and_a_page(&workspace, None, None)
    .await;

  member.wait_for_sync(&private_space.id).await;
  member.wait_for_sync(&private_page.id).await;

  // member has permission to view the private space and private page
  let member_private_space = member.get_view(&private_space.id).await.unwrap();
  assert_eq!(member_private_space.id, private_space.id);
  let member_private_page = member.get_view(&private_page.id).await.unwrap();
  assert_eq!(member_private_page.id, private_page.id);

  // owner has no permission to view the private space and private page
  let error = owner.get_view(&private_space.id).await;
  assert!(error.is_err());
  let error = owner.get_view(&private_page.id).await;
  assert!(error.is_err());
}

// 1. owner creates a workspace
// 2. owner invites the member into the workspace
// 3. member creates a public space and a page in the public space
// 4. verify owner can access the public space and public page
// 5. member creates a private space and a page in the private space
// 6. verify owner can't access the private space and private page before sharing
// 7. verify owner can access the private space and private page after sharing
#[tokio::test]
async fn owner_has_access_to_invited_private_views_test() {
  use_localhost_af_cloud().await;

  let (owner, member) = create_owner_and_member().await;

  let workspace = owner
    .create_a_workspace_and_invite_member(&member, "Member Workspace".to_string())
    .await;

  let (public_space, public_page) = member
    .create_a_public_space_and_a_page(&workspace, None, None)
    .await;
  let (private_space, private_page) = member
    .create_a_private_space_and_a_page(&workspace, None, None)
    .await;

  owner.wait_for_sync(&public_space.id).await;
  owner.wait_for_sync(&public_page.id).await;

  // owner has permission to view the public space and public page
  let owner_public_space = owner.get_view(&public_space.id).await.unwrap();
  assert_eq!(owner_public_space.id, public_space.id);
  let owner_public_page = owner.get_view(&public_page.id).await.unwrap();
  assert_eq!(owner_public_page.id, public_page.id);

  // owner has no permission to view the private space and private page
  let error = owner.get_view(&private_space.id).await;
  assert!(error.is_err());
  let error = owner.get_view(&private_page.id).await;
  assert!(error.is_err());

  // member shares the private space and private page with the owner
  member
    .share_page_with_email(
      &private_space.id,
      &owner.get_email().await,
      AFAccessLevelPB::ReadOnly,
    )
    .await
    .unwrap();

  owner.open_invited_workspace(&workspace.workspace_id).await;

  let access_level = owner.preload_access_level(&private_page.id).await;
  assert_eq!(access_level, AFAccessLevelPB::ReadOnly);

  // owner has permission to view the private space and private page
  let owner_private_space = owner.get_view(&private_space.id).await.unwrap();
  assert_eq!(owner_private_space.id, private_space.id);
  let owner_private_page = owner.get_view(&private_page.id).await.unwrap();
  assert_eq!(owner_private_page.id, private_page.id);
}

// ------ Member + Guest ------

// 1. owner creates a workspace
// 2. owner invites the member into the workspace
// 3. member creates a private space and a page in the private space
// 4. member invites a guest into the workspace
// 5. verify guest can't access the private space and private page before sharing
// 6. verify guest can access the private page after sharing
#[tokio::test]
async fn member_share_a_private_page_with_guest_test() {
  use_localhost_af_cloud().await;

  let (owner, member, guest) = create_owner_member_and_guest().await;

  let workspace = owner
    .create_a_workspace_and_invite_member(&member, "Member Workspace".to_string())
    .await;

  let (private_space, private_page) = member
    .create_a_private_space_and_a_page(&workspace, None, None)
    .await;

  // guest has no permission to view the private space and private page
  let error = guest.get_view(&private_space.id).await;
  assert!(error.is_err());
  let error = guest.get_view(&private_page.id).await;
  assert!(error.is_err());

  // member invites guest to the page
  member
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

  let error = guest.get_view(&private_space.id).await;
  assert!(error.is_err());
  let guest_private_page = guest.get_view_or_panic(&private_page.id).await;
  assert_eq!(guest_private_page.id, private_page.id);
}

// 1. owner creates a workspace
// 2. owner invites the member into the workspace
// 3. member creates a public space and a page in the public space
// 4. member invites a guest into the workspace
// 5. verify guest can't access the public space and public page before sharing
// 6. verify guest can access the public page after sharing
#[tokio::test]
async fn member_share_a_public_page_with_guest_test() {
  use_localhost_af_cloud().await;

  let (owner, member, guest) = create_owner_member_and_guest().await;

  let workspace = owner
    .create_a_workspace_and_invite_member(&member, "Member Workspace".to_string())
    .await;

  let (public_space, public_page) = member
    .create_a_public_space_and_a_page(&workspace, None, None)
    .await;

  // guest has no permission to view the public space and public page
  let error = guest.get_view(&public_space.id).await;
  assert!(error.is_err());
  let error = guest.get_view(&public_page.id).await;
  assert!(error.is_err());

  // member invites guest to the page
  member
    .share_page_with_email(
      &public_page.id,
      &guest.get_email().await,
      AFAccessLevelPB::ReadAndComment,
    )
    .await
    .unwrap();

  // guest has permission to view the public page
  guest.open_invited_workspace(&workspace.workspace_id).await;

  let access_level = guest.preload_access_level(&public_page.id).await;
  assert_eq!(access_level, AFAccessLevelPB::ReadAndComment);

  guest.wait_for_sync(&public_page.id).await;

  let error = guest.get_view(&public_space.id).await;
  assert!(error.is_err());
  let guest_public_page = guest.get_view_or_panic(&public_page.id).await;
  assert_eq!(guest_public_page.id, public_page.id);
}

// 1. owner creates a workspace
// 2. owner invites the member into the workspace
// 3. member creates a private space and a page in the private space
// 4. verify owner can't access the private space and private page before sharing
// 5. member shares the private page with the owner
// 6. verify owner can access the private page after sharing
// Mark this test as ignore because it's not stable.
#[ignore]
#[tokio::test]
async fn member_share_a_private_page_with_owner_test() {
  use_localhost_af_cloud().await;

  let (owner, member) = create_owner_and_member().await;

  let workspace = owner
    .create_a_workspace_and_invite_member(&member, "Member Workspace".to_string())
    .await;

  let (private_space, private_page) = member
    .create_a_private_space_and_a_page(&workspace, None, None)
    .await;

  member.wait_for_sync(&private_space.id).await;
  member.wait_for_sync(&private_page.id).await;

  // owner has no permission to view the private space and private page
  let error = owner.get_view(&private_space.id).await;
  assert!(error.is_err());
  let error = owner.get_view(&private_page.id).await;
  assert!(error.is_err());

  // member shares the private page with the owner
  member
    .share_page_with_email(
      &private_page.id,
      &owner.get_email().await,
      AFAccessLevelPB::ReadOnly,
    )
    .await
    .unwrap();

  // owner has permission to view the private page
  owner.open_invited_workspace(&workspace.workspace_id).await;

  let access_level = owner.preload_access_level(&private_page.id).await;
  assert_eq!(access_level, AFAccessLevelPB::ReadOnly);

  owner.wait_for_sync(&private_page.id).await;

  // owner has permission to view the private page
  let owner_private_page = owner.get_view_or_panic(&private_page.id).await;
  assert_eq!(owner_private_page.id, private_page.id);
}
