use client_api::entity::auth_dto::{MetadataKey, UpdateUserParams, UserMetaData};
use event_integration_test::user_event::use_localhost_af_cloud;
use event_integration_test::EventIntegrationTest;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[tokio::test]
async fn test_user_profile_metadata() {
  use_localhost_af_cloud().await;
  let test = EventIntegrationTest::new().await;
  let _ = test.af_cloud_sign_up().await;

  let user_profile_pb = test.get_user_profile().await.unwrap();
  let uid = user_profile_pb.id;

  // Create metadata with various fields
  let mut metadata = UserMetaData::default();
  metadata.insert_with_key(MetadataKey::Language, "en-US");
  metadata.insert_with_key(MetadataKey::IconUrl, "https://appflowy.com/123/icon.png");
  metadata.insert("theme", "dark");

  // Update user profile with metadata via UpdateUserParams
  let update_params = UpdateUserParams::new()
    .with_name("Test User")
    .with_metadata(metadata.clone());

  test
    .user_manager
    .patch_user_profile(update_params)
    .await
    .unwrap();

  // Verify the metadata was saved to database
  let workspace_id = test.get_current_workspace().await.id;
  let stored_profile = test
    .user_manager
    .get_user_profile_from_disk(uid, &workspace_id)
    .await
    .unwrap();

  // Check metadata fields
  assert_eq!(
    stored_profile
      .metadata
      .get_typed::<String>(MetadataKey::IconUrl),
    Some("https://appflowy.com/123/icon.png".to_string())
  );
  assert_eq!(
    stored_profile.metadata.get_typed(MetadataKey::Language),
    Some("en-US".to_string())
  );
  assert_eq!(
    stored_profile
      .metadata
      .get_typed(MetadataKey::Custom("theme".to_string())),
    Some("dark".to_string())
  );

  // verify the user profile on server
  let user_service = test
    .user_manager
    .cloud_service()
    .unwrap()
    .user_profile_service()
    .unwrap();
  let sever_user_profile = user_service
    .get_user_profile(uid, &workspace_id)
    .await
    .unwrap();
  assert_eq!(
    sever_user_profile.metadata.get_typed(MetadataKey::Language),
    Some("en-US".to_string())
  );
  assert_eq!(
    sever_user_profile
      .metadata
      .get_typed::<String>(MetadataKey::IconUrl),
    Some("https://appflowy.com/123/icon.png".to_string())
  );
}

#[derive(Serialize, Deserialize, Clone, PartialEq, Eq, Debug)]
struct WorkspaceMetadataMap(pub HashMap<String, WorkspaceMetadata>);
#[derive(Serialize, Deserialize, Clone, PartialEq, Eq, Debug)]
struct WorkspaceMetadata {
  pub language: String,
  pub icon_url: String,
}

#[tokio::test]
async fn test_user_profile_metadata_merge() {
  use_localhost_af_cloud().await;
  let test = EventIntegrationTest::new().await;
  let _ = test.af_cloud_sign_up().await;

  let user_profile_pb = test.get_user_profile().await.unwrap();
  let uid = user_profile_pb.id;

  // First update: set initial metadata
  let mut metadata1 = UserMetaData::default();
  metadata1.insert_with_key(MetadataKey::Language, "en-US");
  metadata1.insert("theme", "dark");

  let update_params1 = UpdateUserParams::new()
    .with_name("Test User")
    .with_metadata(metadata1);

  test
    .user_manager
    .patch_user_profile(update_params1)
    .await
    .unwrap();

  // Verify initial metadata was saved
  let workspace_id = test.get_current_workspace().await.id;
  let stored_profile1 = test
    .user_manager
    .get_user_profile_from_disk(uid, &workspace_id)
    .await
    .unwrap();

  assert_eq!(
    stored_profile1.metadata.get_typed(MetadataKey::Language),
    Some("en-US".to_string())
  );
  assert_eq!(
    stored_profile1
      .metadata
      .get_typed(MetadataKey::Custom("theme".to_string())),
    Some("dark".to_string())
  );

  // Second update: add new metadata fields (should merge, not replace)
  let mut metadata2 = UserMetaData::default();
  metadata2.insert_with_key(MetadataKey::IconUrl, "https://appflowy.com/123/icon.png");
  metadata2.insert("timezone", "UTC");

  let update_params2 = UpdateUserParams::new().with_metadata(metadata2);

  test
    .user_manager
    .patch_user_profile(update_params2)
    .await
    .unwrap();

  // Verify metadata was merged (old fields should still exist)
  let stored_profile2 = test
    .user_manager
    .get_user_profile_from_disk(uid, &workspace_id)
    .await
    .unwrap();

  // Check that old metadata still exists
  assert_eq!(
    stored_profile2.metadata.get_typed(MetadataKey::Language),
    Some("en-US".to_string()),
    "Language should still exist after merge"
  );
  assert_eq!(
    stored_profile2
      .metadata
      .get_typed(MetadataKey::Custom("theme".to_string())),
    Some("dark".to_string()),
    "Theme should still exist after merge"
  );

  // Check that new metadata was added
  assert_eq!(
    stored_profile2
      .metadata
      .get_typed::<String>(MetadataKey::IconUrl),
    Some("https://appflowy.com/123/icon.png".to_string()),
    "IconUrl should be added after merge"
  );
  assert_eq!(
    stored_profile2
      .metadata
      .get_typed(MetadataKey::Custom("timezone".to_string())),
    Some("UTC".to_string()),
    "Timezone should be added after merge"
  );

  // Third update: update existing field (should overwrite that field only)
  let mut metadata3 = UserMetaData::default();
  metadata3.insert("theme", "light");

  let update_params3 = UpdateUserParams::new().with_metadata(metadata3);

  test
    .user_manager
    .patch_user_profile(update_params3)
    .await
    .unwrap();

  // Verify only the updated field changed
  let stored_profile3 = test
    .user_manager
    .get_user_profile_from_disk(uid, &workspace_id)
    .await
    .unwrap();

  assert_eq!(
    stored_profile3
      .metadata
      .get_typed(MetadataKey::Custom("theme".to_string())),
    Some("light".to_string()),
    "Theme should be updated to 'light'"
  );
  assert_eq!(
    stored_profile3.metadata.get_typed(MetadataKey::Language),
    Some("en-US".to_string()),
    "Language should still exist after theme update"
  );
  assert_eq!(
    stored_profile3
      .metadata
      .get_typed::<String>(MetadataKey::IconUrl),
    Some("https://appflowy.com/123/icon.png".to_string()),
    "IconUrl should still exist after theme update"
  );
}

#[tokio::test]
async fn test_user_profile_workspace_metadata() {
  use_localhost_af_cloud().await;
  let test = EventIntegrationTest::new().await;
  let _ = test.af_cloud_sign_up().await;

  let user_profile_pb = test.get_user_profile().await.unwrap();
  let uid = user_profile_pb.id;

  let workspace_metadata = WorkspaceMetadata {
    language: "English".to_string(),
    icon_url: "abc".to_string(),
  };
  let map = WorkspaceMetadataMap(HashMap::from([(
    "workspace_1".to_string(),
    workspace_metadata,
  )]));

  // Create metadata with various fields
  let mut metadata = UserMetaData::default();
  metadata.insert_with_key(MetadataKey::Custom("workspace".to_string()), map.clone());
  let update_params = UpdateUserParams::new().with_metadata(metadata.clone());

  test
    .user_manager
    .patch_user_profile(update_params)
    .await
    .unwrap();

  // Verify the metadata was saved to database
  let workspace_id = test.get_current_workspace().await.id;
  let stored_profile = test
    .user_manager
    .get_user_profile_from_disk(uid, &workspace_id)
    .await
    .unwrap();

  // Check metadata fields
  assert_eq!(
    stored_profile
      .metadata
      .get_typed::<WorkspaceMetadataMap>(MetadataKey::Custom("workspace".to_string()))
      .unwrap(),
    map,
  );

  // verify the user profile on server
  let user_service = test
    .user_manager
    .cloud_service()
    .unwrap()
    .user_profile_service()
    .unwrap();
  let sever_user_profile = user_service
    .get_user_profile(uid, &workspace_id)
    .await
    .unwrap();
  assert_eq!(
    sever_user_profile
      .metadata
      .get_typed::<WorkspaceMetadataMap>(MetadataKey::Custom("workspace".to_string()))
      .unwrap(),
    map,
  );
}
