use crate::util::test_unzip;
use collab_entity::CollabType;
use event_integration_test::user_event::use_localhost_af_cloud;
use event_integration_test::EventIntegrationTest;
use flowy_server_pub::QueryCollab;
use uuid::Uuid;

#[tokio::test]
async fn af_cloud_database_import_csv_test() {
  use_localhost_af_cloud().await;
  let test = EventIntegrationTest::new().await;
  test.af_cloud_sign_up().await;

  let workspace_id = test.get_workspace_id().await;
  let space = test
    .create_space(workspace_id, "imported space".to_string())
    .await;
  let parent_id = Uuid::parse_str(&space.id).unwrap();

  let (database_view, _) = test
    .import_csv_from_test_asset("csv_49r_17c", parent_id, test_unzip)
    .await;
  let database = test.get_database(&database_view.id).await.unwrap();
  let num_of_rows = database.rows.len();
  let params = database
    .rows
    .into_iter()
    .map(|r| QueryCollab {
      object_id: Uuid::parse_str(&r.id).unwrap(),
      collab_type: CollabType::DatabaseRow,
    })
    .collect();

  let database_service = test
    .appflowy_core
    .server_provider
    .get_server()
    .unwrap()
    .database_service();
  let object_by_ids = database_service
    .batch_get_database_encode_collab(params, &workspace_id)
    .await
    .unwrap();

  assert_eq!(object_by_ids.len(), num_of_rows);
}
