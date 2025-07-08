use crate::util::test_unzip;
use event_integration_test::EventIntegrationTest;
use flowy_core::DEFAULT_NAME;
use flowy_user_pub::entities::WorkspaceType;
use uuid::Uuid;

#[tokio::test]
async fn anon_user_multiple_workspace_search_test() {
  // SETUP: Initialize test environment with test data
  let user_db_path = test_unzip("./tests/asset", "090_anon_search").unwrap();
  let test =
    EventIntegrationTest::new_with_user_data_path(user_db_path, DEFAULT_NAME.to_string()).await;
  let first_workspace_id = test.get_workspace_id().await;

  // Wait for initial indexing to complete
  test.wait_until_full_indexing_finish().await;
  // TEST CASE 1: Search by page title
  let result = test
    .perform_search_with_workspace("japan", &first_workspace_id)
    .await;
  let local = result[0]
    .as_ref()
    .unwrap()
    .local_search
    .as_ref()
    .expect("expected a local_search_result");

  assert_eq!(
    local.items.len(),
    2,
    "Should find 2 pages with 'japan' in the title"
  );
  assert_eq!(
    local.items[0].display_name, "Japan Skiing",
    "First result should be 'Japan Skiing'"
  );
  assert_eq!(
    local.items[1].display_name, "Japan Food",
    "Second result should be 'Japan Food'"
  );

  // TEST CASE 2: Search by page content
  let result = test
    .perform_search_with_workspace("Niseko", &first_workspace_id)
    .await;
  let local = result[0]
    .as_ref()
    .unwrap()
    .local_search
    .as_ref()
    .expect("expected a local_search_result");

  assert_eq!(
    local.items.len(),
    1,
    "Should find 1 page with 'Niseko' in the content"
  );
  assert_eq!(
    local.items[0].display_name, "Japan Skiing",
    "The page should be 'Japan Skiing'"
  );

  // TEST CASE 3: Create a new document and verify it becomes searchable
  // Create and add content to new document
  let document_title = "My dog";
  let view = test
    .create_and_open_document(
      &first_workspace_id.to_string(),
      document_title.to_string(),
      vec![],
    )
    .await;
  test
    .insert_document_text(
      &view.id,
      "I have maltese dog, he love eating food all the time",
      0,
    )
    .await;

  // Wait for document to be indexed and searchable
  let result = test
    .search_until_get_result("maltese dog", &first_workspace_id, document_title, 30)
    .await;

  let local = result[0]
    .as_ref()
    .unwrap()
    .local_search
    .as_ref()
    .expect("expected a local_search_result");

  assert!(
    local
      .items
      .iter()
      .any(|item| item.display_name.contains(document_title)),
    "New document should be found when searching for its content"
  );

  // TEST CASE 4: Create and search in a second workspace
  // Create and open a new workspace
  let second_workspace_id = Uuid::parse_str(
    &test
      .create_workspace("my second workspace", WorkspaceType::Vault)
      .await
      .workspace_id,
  )
  .unwrap();

  test
    .open_workspace(
      &second_workspace_id.to_string(),
      WorkspaceType::Vault.into(),
    )
    .await;

  // Wait for indexing in the new workspace
  test.wait_until_full_indexing_finish().await;

  // Search in second workspace
  let result = test
    .perform_search_with_workspace("japan", &second_workspace_id)
    .await;
  assert!(
    result[0].as_ref().unwrap().local_search.is_none(),
    "Empty workspace should not have results for 'japan'"
  );

  // TEST CASE 5: Return to first workspace and verify search still works
  test
    .open_workspace(&first_workspace_id.to_string(), WorkspaceType::Vault.into())
    .await;
  test.wait_until_full_indexing_finish().await;
  let result = test
    .perform_search_with_workspace("japan", &first_workspace_id)
    .await;
  assert!(
    !result.is_empty(),
    "First workspace should still have search results after switching workspaces"
  );
}
