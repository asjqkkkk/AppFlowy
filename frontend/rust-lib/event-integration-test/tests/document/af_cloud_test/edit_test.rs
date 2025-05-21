use crate::util::receive_with_timeout;
use event_integration_test::document_event::assert_document_data_equal;
use event_integration_test::user_event::use_localhost_af_cloud;
use event_integration_test::EventIntegrationTest;
use flowy_document::entities::{DocumentSyncState, DocumentSyncStatePB};
use std::time::Duration;
use uuid::Uuid;

#[tokio::test]
async fn af_cloud_edit_document_test() {
  use_localhost_af_cloud().await;
  let test = EventIntegrationTest::new().await;
  test.af_cloud_sign_up().await;
  test.wait_ws_connected().await.unwrap();

  // create document and then insert content
  let current_workspace = test.get_current_workspace().await;
  let view = test
    .create_and_open_document(&current_workspace.id, "my document".to_string(), vec![])
    .await;
  test.insert_document_text(&view.id, "hello world", 0).await;

  let document_id = view.id;
  println!("document_id: {}", document_id);

  // wait all update are send to the remote
  let rx = test
    .notification_sender
    .subscribe_with_condition::<DocumentSyncStatePB, _>(&document_id, |pb| {
      pb.value == DocumentSyncState::SyncFinished
    });
  let _ = receive_with_timeout(rx, Duration::from_secs(30)).await;

  let document_data = test.get_document_data(&document_id).await;
  let doc_state = test.get_document_doc_state(&document_id).await;
  assert!(!doc_state.is_empty());
  assert_document_data_equal(&doc_state, &document_id, document_data);
}

#[tokio::test]
async fn af_cloud_multiple_user_edit_document_test() {
  use_localhost_af_cloud().await;
  let test_1 = EventIntegrationTest::new().await;
  let profile = test_1.af_cloud_sign_up().await;
  test_1.wait_ws_connected().await.unwrap();

  let test_2 = EventIntegrationTest::new().await;
  test_2.af_cloud_sign_up_with_email(&profile.email).await;
  let views = test_2.get_all_workspace_views().await;
  assert_eq!(views.len(), 2);

  // create document and then insert content
  let current_workspace = test_1.get_current_workspace().await;
  let view = test_1
    .create_and_open_document(
      &current_workspace.id,
      "my shared document".to_string(),
      vec![],
    )
    .await;
  test_1
    .insert_document_text(&view.id, "hello world", 0)
    .await;

  // wait all update are send to the remote
  let rx = test_1
    .notification_sender
    .subscribe_with_condition::<DocumentSyncStatePB, _>(&view.id, |pb| {
      pb.value == DocumentSyncState::SyncFinished
    });
  let _ = receive_with_timeout(rx, Duration::from_secs(30)).await;

  tokio::time::sleep(Duration::from_secs(10)).await;
  let mut views = test_2.get_all_workspace_views().await;
  views.sort_by(|a, b| a.create_time.cmp(&b.create_time));
  dbg!(&views.iter().map(|v| v.name.clone()).collect::<Vec<_>>());
  assert_eq!(views.len(), 3);
  assert_eq!(views[2].name, "my shared document");

  let document_data = test_2.get_document_text(&view.id).await;
  assert_eq!(document_data.text, "hello world".to_string());
}

#[tokio::test]
async fn af_cloud_multiple_user_offline_then_online_edit_document_test() {
  use_localhost_af_cloud().await;
  let test_1 = EventIntegrationTest::new().await;
  let profile = test_1.af_cloud_sign_up().await;
  let workspace_id = test_1
    .get_current_workspace()
    .await
    .id
    .parse::<Uuid>()
    .unwrap();
  test_1.wait_ws_connected().await.unwrap();
  test_1
    .user_manager
    .disconnect_workspace_ws_conn(&workspace_id)
    .await
    .unwrap();

  let test_2 = EventIntegrationTest::new().await;
  test_2.af_cloud_sign_up_with_email(&profile.email).await;
  let views = test_2.get_all_workspace_views().await;
  assert_eq!(views.len(), 2);

  // create document and then insert content
  let current_workspace = test_1.get_current_workspace().await;
  let view = test_1
    .create_and_open_document(
      &current_workspace.id,
      "my shared document".to_string(),
      vec![],
    )
    .await;
  test_1
    .insert_document_text(&view.id, "hello world", 0)
    .await;
  test_1
    .user_manager
    .connect_workspace_ws_conn(&workspace_id)
    .await
    .unwrap();

  // wait all update are send to the remote
  let rx = test_1
    .notification_sender
    .subscribe_with_condition::<DocumentSyncStatePB, _>(&view.id, |pb| {
      pb.value == DocumentSyncState::SyncFinished
    });
  let _ = receive_with_timeout(rx, Duration::from_secs(30)).await;
  tokio::time::sleep(Duration::from_secs(10)).await;

  let mut views = test_2.get_all_workspace_views().await;
  views.sort_by(|a, b| a.create_time.cmp(&b.create_time));
  dbg!(&views.iter().map(|v| v.name.clone()).collect::<Vec<_>>());
  assert_eq!(views.len(), 3);
  assert_eq!(views[2].name, "my shared document");

  let document_data = test_2.get_document_text(&view.id).await;
  assert_eq!(document_data.text, "hello world".to_string());
}
