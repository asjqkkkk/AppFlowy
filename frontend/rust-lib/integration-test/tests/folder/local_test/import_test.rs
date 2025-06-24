use crate::util::test_unzip;
use event_integration_test::folder_event::gen_database_import_data;
use event_integration_test::EventIntegrationTest;
use flowy_core::DEFAULT_NAME;
use flowy_error::ErrorCode;

#[tokio::test]
async fn import_492_row_csv_file_test() {
  // csv_500r_15c.csv is a file with 492 rows and 17 columns
  let file_name = "csv_492r_17c.csv".to_string();
  let csv_file_path = test_unzip("./tests/asset", &file_name).unwrap();

  let csv_string = std::fs::read_to_string(csv_file_path).unwrap();
  let test = EventIntegrationTest::new_with_name(DEFAULT_NAME).await;
  test.sign_up_as_anon().await;

  let workspace_id = test.get_current_workspace().await.id;
  let import_data = gen_database_import_data(file_name, csv_string, workspace_id);

  let views = test.import_data(import_data).await.unwrap().items;
  let view_id = views[0].clone().id;
  let database = test.get_database_or_panic(&view_id).await;
  assert_eq!(database.rows.len(), 492);
}

#[tokio::test]
async fn import_10240_row_csv_file_test() {
  // csv_22577r_15c.csv is a file with 10240 rows and 15 columns
  let file_name = "csv_10240r_15c.csv".to_string();
  let csv_file_path = test_unzip("./tests/asset", &file_name).unwrap();

  let csv_string = std::fs::read_to_string(csv_file_path).unwrap();
  let test = EventIntegrationTest::new_with_name(DEFAULT_NAME).await;
  test.sign_up_as_anon().await;

  let workspace_id = test.get_current_workspace().await.id;
  let import_data = gen_database_import_data(file_name, csv_string, workspace_id);

  let err = test.import_data(import_data).await.unwrap_err();
  assert_eq!(err.code, ErrorCode::InvalidParams);
}
