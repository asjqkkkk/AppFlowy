use crate::folder::af_cloud::guest_editor_test::util::{
  create_owner_member_and_guest, AccessLevelTest,
};
use event_integration_test::user_event::use_localhost_af_cloud;
use event_integration_test::EventIntegrationTest;
use flowy_folder::entities::AFAccessLevelPB;

// Guest can't invite another guest
// 1. owner creates a workspace
// 2. owner creates a private page
// 3. owner shares the page with guest1
// 4. guest1 tries to share the page with guest2
// 5. verify that guest1 can't share the page
#[tokio::test]
async fn guest_cannot_invite_another_guest_test() {
  use_localhost_af_cloud().await;

  let owner = EventIntegrationTest::new().await;
  owner.af_cloud_sign_up().await;

  let guest1 = EventIntegrationTest::new().await;
  let guest1_email = guest1.af_cloud_sign_up().await.email;

  let guest2 = EventIntegrationTest::new().await;
  let guest2_email = guest2.af_cloud_sign_up().await.email;

  let workspace = owner
    .create_and_open_workspace("Guest cannot invite another guest".to_string())
    .await;
  let (_private_space, private_page) = owner
    .create_a_private_space_and_a_page(&workspace, None, None)
    .await;

  owner
    .share_page_with_email(
      &private_page.id,
      &guest1_email,
      AFAccessLevelPB::ReadAndComment,
    )
    .await
    .unwrap();

  guest1.open_invited_workspace(&workspace.workspace_id).await;
  guest1.preload_access_level(&private_page.id).await;
  guest1.wait_for_sync(&private_page.id).await;

  let result = guest1
    .share_page_with_email(&private_page.id, &guest2_email, AFAccessLevelPB::ReadOnly)
    .await;
  assert!(result.is_err());

  let error = guest2.get_view(&private_page.id).await;
  assert!(error.is_err());
}

// Guest can't see member email when both are invited to a private page
// 1. owner creates a workspace and invites a member
// 2. owner creates a private page
// 3. owner shares the page with the member
// 4. owner shares the page with a guest
// 5. verify guest can only see 2 people in shared users (owner and guest)
// 6. verify member can see all 3 people in shared users
#[tokio::test]
async fn guest_cannot_see_member_email_in_shared_users_test() {
  use_localhost_af_cloud().await;

  let (owner, member, guest) = create_owner_member_and_guest().await;

  let owner_email = owner.get_email().await;
  let member_email = member.get_email().await;
  let guest_email = guest.get_email().await;

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
  let shared_users = member.get_shared_users(&private_page.id).await.unwrap();
  // only owner + member in the shared users list
  assert_eq!(shared_users.items.len(), 2);

  // owner shares the private page wit the guest
  owner
    .share_page_with_email(&private_page.id, &guest_email, AFAccessLevelPB::ReadOnly)
    .await
    .unwrap();

  guest.open_invited_workspace(&workspace.workspace_id).await;

  let access_level = guest.preload_access_level(&private_page.id).await;
  assert_eq!(access_level, AFAccessLevelPB::ReadOnly);

  // owner can see all 3 people in shared users
  {
    let owner_shared_users = owner.get_shared_users(&private_page.id).await.unwrap();
    assert_eq!(owner_shared_users.items.len(), 3);

    let owner_emails: Vec<String> = owner_shared_users
      .items
      .iter()
      .map(|u| u.email.clone())
      .collect();
    assert!(owner_emails.contains(&owner_email));
    assert!(owner_emails.contains(&member_email));
    assert!(owner_emails.contains(&guest_email));
  }

  // member can see all 3 people in shared users
  {
    let member_shared_users = member.get_shared_users(&private_page.id).await.unwrap();
    assert_eq!(member_shared_users.items.len(), 3);

    let member_emails: Vec<String> = member_shared_users
      .items
      .iter()
      .map(|u| u.email.clone())
      .collect();
    assert!(member_emails.contains(&owner_email));
    assert!(member_emails.contains(&member.get_email().await));
    assert!(member_emails.contains(&guest.get_email().await));
  }

  // guest can only see owner and guest in the shared users list
  {
    let guest_shared_users = guest.get_shared_users(&private_page.id).await.unwrap();
    // only owner + guest in the shared users list
    assert_eq!(shared_users.items.len(), 2);

    let guest_emails: Vec<String> = guest_shared_users
      .items
      .iter()
      .map(|u| u.email.clone())
      .collect();

    assert!(guest_emails.contains(&owner_email));
    assert!(guest_emails.contains(&guest.get_email().await));
    assert!(!guest_emails.contains(&member.get_email().await));
  }
}
