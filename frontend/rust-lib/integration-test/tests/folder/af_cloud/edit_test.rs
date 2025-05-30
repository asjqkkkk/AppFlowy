use crate::util::receive_with_timeout;
use event_integration_test::document_event::assert_document_data_equal;
use event_integration_test::user_event::use_localhost_af_cloud;
use event_integration_test::EventIntegrationTest;
use flowy_document::entities::{DocumentSyncState, DocumentSyncStatePB};
use std::time::Duration;

#[tokio::test]
async fn af_cloud_offline_edit_folder_then_sync_test() {
  use_localhost_af_cloud().await;
  let test = EventIntegrationTest::new().await;
  test.af_cloud_sign_up().await;
  test.disconnect_ws().await.unwrap();

  // create space
  let current_workspace = test.get_current_workspace().await;
}
