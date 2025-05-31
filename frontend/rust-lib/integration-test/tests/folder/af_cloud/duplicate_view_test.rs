use crate::util::unzip;
use anyhow::anyhow;
use event_integration_test::folder_event::parse_csv_string;
use event_integration_test::user_event::use_localhost_af_cloud;
use event_integration_test::{retry_with_backoff, EventIntegrationTest};
use uuid::Uuid;

#[tokio::test]
async fn af_cloud_folder_sync_duplicated_document_test() {
  use_localhost_af_cloud().await;

  // Setup two test clients
  let test = EventIntegrationTest::new().await;
  let email = test.af_cloud_sign_up().await.email;
  let workspace_id = test.get_workspace_id().await;

  let test_2 = EventIntegrationTest::new().await;
  test_2.af_cloud_sign_in_with_email(&email).await.unwrap();

  // Create a test space
  let space = test
    .create_space(workspace_id, "Test space".to_string())
    .await;
  assert!(space.extra.is_some());

  // Create 3 documents with consistent content
  let parent_id = Uuid::parse_str(&space.id).unwrap();
  let document_count = 3;
  for i in 0..document_count {
    let document = test
      .create_document(&format!("my document {}", i), parent_id)
      .await;
    test
      .insert_document_text(&document.id, &format!("hello duplicate {}", i), 0)
      .await;
  }

  // Duplicate the view and verify structure
  let duplicated_view = test.duplicate_view_or_panic(parent_id, true).await;
  let duplicated_view_child_views = test
    .get_view(&duplicated_view.id)
    .await
    .unwrap()
    .child_views;

  // Verify all duplicated document contents are consistent
  assert_eq!(duplicated_view_child_views.len(), document_count);
  for (index, view) in duplicated_view_child_views.iter().enumerate() {
    let text = test.get_document_text(&view.id).await.unwrap().text;
    assert_eq!(text, format!("hello duplicate {}", index));
  }

  // Wait for original documents to sync to client 2
  let cloned_test_2 = test_2.clone();
  retry_with_backoff(|| async {
    let view = cloned_test_2.get_view(&parent_id.to_string()).await?;
    if view.child_views.len() == document_count {
      for i in 0..document_count {
        assert_eq!(view.child_views[i].name, format!("my document {}", i));
      }
      Ok(())
    } else {
      Err(anyhow!("Original views not synced yet"))
    }
  })
  .await
  .unwrap();

  // Wait for duplicated documents to sync to client 2 and verify content consistency
  retry_with_backoff(|| async {
    let view = test_2.get_view(&duplicated_view.id).await?;
    if view.child_views.len() == document_count {
      for i in 0..document_count {
        assert_eq!(view.child_views[i].name, format!("my document {}", i));

        let text = test_2
          .get_document_text(&view.child_views[i].id)
          .await?
          .text;
        assert_eq!(text, format!("hello duplicate {}", i));
      }
      Ok(())
    } else {
      Err(anyhow!("Duplicated views not synced yet"))
    }
  })
  .await
  .unwrap();

  drop(test);
}

#[tokio::test]
async fn af_cloud_folder_sync_duplicated_database_test() {
  use_localhost_af_cloud().await;

  // Setup two test clients
  let test = EventIntegrationTest::new().await;
  let email = test.af_cloud_sign_up().await.email;
  let workspace_id = test.get_workspace_id().await;

  let test_2 = EventIntegrationTest::new().await;
  test_2.af_cloud_sign_in_with_email(&email).await.unwrap();

  // Create a test space
  let space = test
    .create_space(workspace_id, "Test space".to_string())
    .await;
  assert!(space.extra.is_some());

  let parent_id = Uuid::parse_str(&space.id).unwrap();
  let (database_view, csv_string) = test
    .import_csv_from_test_asset("csv_49r_17c", parent_id, unzip)
    .await;

  let database = test.get_database(&database_view.id).await.unwrap();
  assert_eq!(database.rows.len(), 49);

  let duplicated_view = test
    .duplicate_view_or_panic(Uuid::parse_str(&database_view.id).unwrap(), true)
    .await;

  // Wait for original documents to sync to client 2
  let cloned_test_2 = test_2.clone();
  let cloned_csv_string = csv_string.clone();
  retry_with_backoff(|| async {
    let csv = cloned_test_2.export_database(&database_view.id).await?;
    let database = cloned_test_2.get_database(&database_view.id).await.unwrap();
    assert_eq!(database.rows.len(), 49);
    dbg!("csv content", &csv);

    let exported_csv_data = parse_csv_string(&csv)?;
    let original_csv_data = parse_csv_string(&cloned_csv_string)?;
    if exported_csv_data.len() != original_csv_data.len() {
      return Err(anyhow!("syncing database rows"));
    }
    assert_eq!(exported_csv_data, original_csv_data);
    Ok(())
  })
  .await
  .unwrap();

  // Wait for original documents to sync to client 2
  retry_with_backoff(|| async {
    let csv = test_2.export_database(&duplicated_view.id).await?;
    dbg!("duplicated csv content", &csv);

    let exported_csv_data = parse_csv_string(&csv)?;
    let original_csv_data = parse_csv_string(&csv_string)?;
    if exported_csv_data.len() != original_csv_data.len() {
      return Err(anyhow!("syncing database rows"));
    }
    assert_eq!(exported_csv_data, original_csv_data);
    Ok(())
  })
  .await
  .unwrap();
}
