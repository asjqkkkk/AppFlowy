use event_integration_test::user_event::use_localhost_af_cloud;
use event_integration_test::EventIntegrationTest;

#[tokio::test]
async fn sever_info_set_refresh_test() {
  use_localhost_af_cloud().await;

  let test = EventIntegrationTest::new().await;

  let (tx, rx) = tokio::sync::oneshot::channel();
  test.user_manager.sync_server_info(Some(tx));

  let server_info = rx.await.unwrap().unwrap();
  dbg!(&server_info);
}
