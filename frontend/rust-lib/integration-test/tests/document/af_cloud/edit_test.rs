use crate::util::receive_with_timeout;
use event_integration_test::document_event::assert_document_data_equal;
use event_integration_test::user_event::use_localhost_af_cloud;
use event_integration_test::{retry_with_backoff, EventIntegrationTest};
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
async fn af_cloud_document_undo_redo_test() {
  use_localhost_af_cloud().await;
  let test = EventIntegrationTest::new().await;
  test.af_cloud_sign_up().await;

  // create document and then insert content
  let current_workspace = test.get_current_workspace().await;
  let view = test
    .create_and_open_document(&current_workspace.id, "my document".to_string(), vec![])
    .await;
  test.insert_document_text(&view.id, "hello world", 0).await;

  let text = test.get_document_text(&view.id).await.unwrap().text;
  assert_eq!(text, "hello world");

  test.undo(view.id.clone()).await;
  let text = test.get_document_text(&view.id).await.unwrap().text;
  assert_eq!(text, "");

  test.redo(view.id.clone()).await;
  let text = test.get_document_text(&view.id).await.unwrap().text;
  assert_eq!(text, "hello world");
}

#[tokio::test]
async fn af_cloud_multiple_user_edit_document_test() {
  use_localhost_af_cloud().await;
  let test_1 = EventIntegrationTest::new().await;
  let profile = test_1.af_cloud_sign_up().await;
  test_1.wait_ws_connected().await.unwrap();

  let test_2 = EventIntegrationTest::new().await;
  test_2.af_cloud_sign_up_with_email(&profile.email).await;

  // Verify initial views count with retry
  retry_with_backoff(|| async {
    let views = test_2.get_all_workspace_views().await;
    if views.len() != 2 {
      return Err(anyhow::anyhow!(
        "Expected 2 initial views, got {}",
        views.len()
      ));
    }
    Ok(())
  })
  .await
  .unwrap();

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

  // Retry until the new document appears on test_2 and has correct content
  retry_with_backoff(|| async {
    let mut views = test_2.get_all_workspace_views().await;
    views.sort_by(|a, b| a.create_time.cmp(&b.create_time));

    if views.len() != 3 {
      return Err(anyhow::anyhow!("Expected 3 views, got {}", views.len()));
    }

    if views[2].name != "my shared document" {
      return Err(anyhow::anyhow!(
        "Expected document name 'my shared document', got '{}'",
        views[2].name
      ));
    }

    let document_data = test_2.get_document_text_or_panic(&view.id).await;
    if document_data.text != "hello world" {
      return Err(anyhow::anyhow!(
        "Expected document text 'hello world', got '{}'",
        document_data.text
      ));
    }

    Ok(())
  })
  .await
  .unwrap();
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
  test_1.disconnect_ws().await.unwrap();

  let test_2 = EventIntegrationTest::new().await;
  test_2.af_cloud_sign_up_with_email(&profile.email).await;

  // Verify initial views count with retry
  retry_with_backoff(|| async {
    let views = test_2.get_all_workspace_views().await;
    if views.len() != 2 {
      return Err(anyhow::anyhow!(
        "Expected 2 initial views, got {}",
        views.len()
      ));
    }
    Ok(())
  })
  .await
  .unwrap();

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
    .start_ws_connect_manually(&workspace_id)
    .await
    .unwrap();

  // wait all update are send to the remote
  let rx = test_1
    .notification_sender
    .subscribe_with_condition::<DocumentSyncStatePB, _>(&view.id, |pb| {
      pb.value == DocumentSyncState::SyncFinished
    });
  let _ = receive_with_timeout(rx, Duration::from_secs(30)).await;

  // Retry until the new document appears on test_2 and has correct content
  retry_with_backoff(|| async {
    let mut views = test_2.get_all_workspace_views().await;
    views.sort_by(|a, b| a.create_time.cmp(&b.create_time));

    if views.len() != 3 {
      return Err(anyhow::anyhow!("Expected 3 views, got {}", views.len()));
    }

    if views[2].name != "my shared document" {
      return Err(anyhow::anyhow!(
        "Expected document name 'my shared document', got '{}'",
        views[2].name
      ));
    }

    let document_data = test_2.get_document_text_or_panic(&view.id).await;
    if document_data.text != "hello world" {
      return Err(anyhow::anyhow!(
        "Expected document text 'hello world', got '{}'",
        document_data.text
      ));
    }

    Ok(())
  })
  .await
  .unwrap();
}
