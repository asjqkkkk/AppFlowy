use crate::util::test_unzip;
use event_integration_test::user_event::use_localhost_af_cloud;
use event_integration_test::EventIntegrationTest;
use flowy_user_pub::entities::WorkspaceType;
use flowy_user_pub::workspace_collab::adaptor_trait::ConsumerType;
use uuid::Uuid;

#[tokio::test]
async fn local_ai_test_vault_workspace_ai_search() {
  use_localhost_af_cloud().await;
  let test = EventIntegrationTest::new().await;
  let _ = test.af_cloud_sign_up().await;
  let vault_workspace_id = Uuid::parse_str(
    &test
      .create_workspace("my vault workspace", WorkspaceType::Vault)
      .await
      .workspace_id,
  )
  .unwrap();

  test
    .open_workspace(&vault_workspace_id.to_string(), WorkspaceType::Vault.into())
    .await;

  test.toggle_local_ai().await;

  let search_space = test
    .create_public_space(vault_workspace_id, "search space".to_string())
    .await;
  let space_id = Uuid::parse_str(&search_space.id).unwrap();

  let (japan_trip, _) = test
    .import_md_from_test_asset("japan_trip", space_id, test_unzip)
    .await;

  let (tennis_weekly_plan, _) = test
    .import_md_from_test_asset("tennis_weekly_plan", space_id, test_unzip)
    .await;

  let writer = test
    .server_provider
    .indexed_data_writer
    .as_ref()
    .unwrap()
    .upgrade()
    .unwrap();
  let mut observer = writer.subscribe_collab_consumed();
  let mut ids = vec![japan_trip.id.clone(), tennis_weekly_plan.id.clone()];

  let timeout = tokio::time::sleep(tokio::time::Duration::from_secs(60));
  tokio::pin!(timeout);

  loop {
    tokio::select! {
      _ = &mut timeout => {
        panic!("Timeout waiting for documents to be indexed after 60 seconds. Remaining documents: {:?}", ids);
      }
      event = observer.recv() => {
        if let Ok(event) = event {
          if event.consumer_type == ConsumerType::Embedding {
            if let Some(pos) = ids.iter().position(|id| id == &event.object_id.to_string()) {
              ids.remove(pos);
              if ids.is_empty() {
                break;
              }
            }
          }
        } else {
          panic!("Observer channel closed unexpectedly");
        }
      }
    }
  }

  let result = test.perform_search("Ski japan").await;
  dbg!(&result);
  assert!(result
    .into_iter()
    .flat_map(|v| v.ok())
    .any(|v| { v.search_summary.is_some() }));

  let result = test.perform_search("tennis training plan").await;
  dbg!(&result);
  assert!(result
    .into_iter()
    .flat_map(|v| v.ok())
    .any(|v| { v.search_summary.is_some() }));
}
