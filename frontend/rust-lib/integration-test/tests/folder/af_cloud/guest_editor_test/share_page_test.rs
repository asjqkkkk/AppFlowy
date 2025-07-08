use event_integration_test::user_event::use_localhost_af_cloud;
use flowy_folder::entities::{AFAccessLevelPB, RepeatedSharedUserPB};

use crate::folder::af_cloud::guest_editor_test::util::{create_2_clients, AccessLevelTest};

// Helper function to assert shared users and their access levels
fn assert_shared_users(
  shared_users: &RepeatedSharedUserPB,
  expected_users: Vec<(&str, AFAccessLevelPB)>,
) {
  assert_eq!(shared_users.items.len(), expected_users.len());

  for (i, (expected_email, expected_access_level)) in expected_users.iter().enumerate() {
    assert_eq!(shared_users.items[i].email, *expected_email);
    assert_eq!(shared_users.items[i].access_level, *expected_access_level);
  }
}

// invite a guest into the getting started page
#[tokio::test]
async fn af_cloud_share_page_with_email_test() {
  use_localhost_af_cloud().await;

  let (client_1, client_2) = create_2_clients().await;
  let client_2_email = client_2.get_email().await;

  let views = client_1.get_all_views().await;
  let getting_started_view = views.iter().find(|v| v.name == "Getting started");
  let view = getting_started_view.unwrap();

  let shared_users = client_1.get_shared_users(&view.id).await.unwrap();
  let client_1_email = client_1.get_user_profile().await.unwrap().email;
  assert_shared_users(
    &shared_users,
    vec![(&client_1_email, AFAccessLevelPB::FullAccess)],
  );

  client_1
    .share_page_with_email(&view.id, &client_2_email, AFAccessLevelPB::ReadAndComment)
    .await
    .unwrap();

  // new user is added to the shared users list
  let shared_users = client_1.get_shared_users(&view.id).await.unwrap();
  assert_shared_users(
    &shared_users,
    vec![
      (&client_1_email, AFAccessLevelPB::FullAccess),
      (&client_2_email, AFAccessLevelPB::ReadAndComment),
    ],
  );

  let _ = client_2
    .open_invited_workspace(&client_1.get_current_workspace().await.id)
    .await;

  let shared_users = client_2.get_shared_users(&view.id).await.unwrap();
  assert_eq!(shared_users.items.len(), 2);

  let access_level = client_1
    .get_user_access_level(&view.id, &client_2_email)
    .await
    .unwrap();
  assert_eq!(access_level, AFAccessLevelPB::ReadAndComment);
}

// Remove a guest from the getting started page
#[tokio::test]
async fn af_cloud_remove_guest_from_page_test() {
  use_localhost_af_cloud().await;

  let (client_1, client_2) = create_2_clients().await;
  let client_2_email = client_2.get_email().await;

  // get all views and get the getting started page
  let views = client_1.get_all_views().await;
  let getting_started_view = views.iter().find(|v| v.name == "Getting started");
  let view = getting_started_view.unwrap();

  client_1
    .share_page_with_email(&view.id, &client_2_email, AFAccessLevelPB::ReadAndComment)
    .await
    .unwrap();

  // now the count should be 2
  let shared_users = client_1.get_shared_users(&view.id).await.unwrap();
  assert_eq!(shared_users.items.len(), 2);

  // remove the second client from the getting started page
  client_1
    .remove_user_from_shared_page(&view.id, &client_2_email)
    .await
    .unwrap();

  // the second client is removed from the getting started page
  let shared_users = client_1.get_shared_users(&view.id).await.unwrap();
  assert_eq!(shared_users.items.len(), 1);
}

// Change the access level of a shared user
#[tokio::test]
async fn af_cloud_change_access_level_of_shared_user_test() {
  use_localhost_af_cloud().await;

  let (client_1, client_2) = create_2_clients().await;
  let client_2_email = client_2.get_email().await;

  let views = client_1.get_all_views().await;
  let getting_started_view = views.iter().find(|v| v.name == "Getting started");
  let view = getting_started_view.unwrap();

  client_1
    .share_page_with_email(&view.id, &client_2_email, AFAccessLevelPB::ReadAndComment)
    .await
    .unwrap();

  let shared_users = client_1.get_shared_users(&view.id).await.unwrap();
  assert_eq!(shared_users.items.len(), 2);
  assert_eq!(
    shared_users.items[1].access_level,
    AFAccessLevelPB::ReadAndComment
  );

  client_1
    .share_page_with_email(&view.id, &client_2_email, AFAccessLevelPB::ReadOnly)
    .await
    .unwrap();

  let shared_users = client_1.get_shared_users(&view.id).await.unwrap();
  assert_eq!(shared_users.items.len(), 2);
  assert_eq!(
    shared_users.items[1].access_level,
    AFAccessLevelPB::ReadOnly
  );
}
