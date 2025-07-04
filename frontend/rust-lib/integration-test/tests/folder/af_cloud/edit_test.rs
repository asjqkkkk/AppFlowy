use event_integration_test::folder_event::parse_csv_string;
use event_integration_test::user_event::use_localhost_af_cloud;
use event_integration_test::{retry_with_backoff, EventIntegrationTest};
use flowy_folder::entities::ViewPB;
use uuid::Uuid;

use crate::util::test_unzip;

#[tokio::test]
async fn af_cloud_two_client_offline_edit_then_sync_space_test() {
  use_localhost_af_cloud().await;
  // Phase 1: Setup two test clients
  let (test, test2, _) = setup_two_clients().await;

  // Phase 2: Create content offline
  let (document, content, space_1) = create_markdown_content_offline(&test).await;
  let (database_view, original_csv_data, space_2) = create_csv_content_offline(&test2).await;

  // Phase 3: Reconnect and sync
  reconnect_and_sync(&test, &test2).await;

  // Phase 4: Verify sync completed
  verify_spaces_synced(&test, &test2, &space_1, &space_2).await;

  // Phase 5: Verify content integrity
  verify_content_synced(
    &test,
    &test2,
    &document,
    &content,
    &database_view,
    &original_csv_data,
  )
  .await;
}

async fn setup_two_clients() -> (EventIntegrationTest, EventIntegrationTest, String) {
  let test = EventIntegrationTest::new().await;
  let email = test.af_cloud_sign_up().await.email;
  test.disconnect_ws().await.unwrap();

  let test2 = EventIntegrationTest::new().await;
  test2.af_cloud_sign_in_with_email(&email).await.unwrap();
  test2.disconnect_ws().await.unwrap();

  (test, test2, email)
}

async fn create_markdown_content_offline(test: &EventIntegrationTest) -> (ViewPB, String, ViewPB) {
  let space_1 = test
    .create_public_space(test.get_workspace_id().await, "Test space 1".to_string())
    .await;
  let space_1_id = Uuid::parse_str(&space_1.id).unwrap();

  let (document, content) = test
    .import_md_from_test_asset("japan_trip", space_1_id, test_unzip)
    .await;

  // Verify initial content
  let text = test
    .get_document_text(&document.id)
    .await
    .unwrap()
    .text
    .replace("\n", "");
  assert_eq!(text, content.replace("\n", ""));

  (document, content, space_1)
}

async fn create_csv_content_offline(
  test2: &EventIntegrationTest,
) -> (ViewPB, Vec<Vec<String>>, ViewPB) {
  let space_2 = test2
    .create_public_space(test2.get_workspace_id().await, "Test space 2".to_string())
    .await;
  let parent_id = Uuid::parse_str(&space_2.id).unwrap();

  let (database_view, csv_string) = test2
    .import_csv_from_test_asset("csv_10r_17c", parent_id, test_unzip)
    .await;

  // Verify initial content
  let original_csv_data = parse_csv_string(&csv_string).unwrap();
  let exported_csv_data =
    parse_csv_string(&test2.export_database(&database_view.id).await.unwrap()).unwrap();
  assert_eq!(exported_csv_data, original_csv_data);

  (database_view, original_csv_data, space_2)
}

async fn reconnect_and_sync(test: &EventIntegrationTest, test2: &EventIntegrationTest) {
  // Reconnect both clients to trigger sync
  let _ = test.connect_ws().await;
  let _ = test2.connect_ws().await;
}

async fn verify_spaces_synced(
  test: &EventIntegrationTest,
  test2: &EventIntegrationTest,
  space_1: &ViewPB,
  space_2: &ViewPB,
) {
  let ids = [space_1.id.clone(), space_2.id.clone()];

  // Verify test can see both spaces
  retry_with_backoff(|| async {
    let mut views = test.get_all_workspace_views().await;
    // let workspace_id = test.get_workspace_id().await;
    // let collab = test
    //   .get_disk_collab(&workspace_id.to_string())
    //   .await
    //   .unwrap();
    views.retain(|v| ids.contains(&v.id));
    (views.len() >= 2)
      .then_some(())
      .ok_or_else(|| anyhow::anyhow!("Expected spaces:{:?} in test, got {:#?}\n", ids, views,))
      .map(|_| assert_eq!(views.len(), 2))
  })
  .await
  .unwrap();

  // Verify test2 can see both spaces
  retry_with_backoff(|| async {
    let mut views = test2.get_all_workspace_views().await;
    let origin = views.clone();
    views.retain(|v| ids.contains(&v.id));

    (views.len() >= 2)
      .then_some(())
      .ok_or_else(|| {
        anyhow::anyhow!(
          "Expected 2 views in test2, got {:#?}\n origin:{:#?}",
          views,
          origin
        )
      })
      .map(|_| assert_eq!(views.len(), 2))
  })
  .await
  .unwrap();
}

async fn verify_content_synced(
  test: &EventIntegrationTest,
  test2: &EventIntegrationTest,
  document: &ViewPB,
  content: &str,
  database_view: &ViewPB,
  original_csv_data: &Vec<Vec<String>>,
) {
  // Verify test2 can access the markdown document created by test
  retry_with_backoff(|| async {
    let views = test2.get_all_views().await;
    views
      .iter()
      .find(|v| v.id == document.id)
      .ok_or_else(|| anyhow::anyhow!("Document not found in test2 after sync"))?;

    // Get and verify document content
    let synced_text = test2
      .get_document_text(&document.id)
      .await?
      .text
      .replace("\n", "");

    (synced_text == content.replace("\n", ""))
      .then_some(())
      .ok_or_else(|| anyhow::anyhow!("Document content mismatch after sync"))
  })
  .await
  .unwrap();

  // Verify test can access the database view created by test2
  retry_with_backoff(|| async {
    let views = test.get_all_views().await;
    views
      .iter()
      .find(|v| v.id == database_view.id)
      .ok_or_else(|| anyhow::anyhow!("Database view not found in test after sync"))?;

    // Get and verify database content
    let synced_csv_data = test.export_database(&database_view.id).await?;
    let parsed_synced_data = parse_csv_string(&synced_csv_data)?;

    (&parsed_synced_data == original_csv_data)
      .then_some(())
      .ok_or_else(|| anyhow::anyhow!("Database content mismatch after sync"))
  })
  .await
  .unwrap();
}
