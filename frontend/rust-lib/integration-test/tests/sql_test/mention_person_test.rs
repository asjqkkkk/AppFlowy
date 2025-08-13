use client_api::entity::MentionablePersonType;
use event_integration_test::user_event::use_localhost_af_cloud;
use event_integration_test::EventIntegrationTest;
use flowy_folder_pub::sql::mentionable_person_sql::{
  delete_workspace_all_mentionable_persons, delete_workspace_mentionable_person,
  select_all_mentionable_persons, select_mentionable_person, select_mentionable_persons_by_role,
  update_last_mentioned_at, update_role, upsert_mentionable_person, MentionablePersonTable,
};
use uuid::Uuid;

#[tokio::test]
async fn mentionable_person_crud_upsert_test() {
  use_localhost_af_cloud().await;
  let test = EventIntegrationTest::new().await;
  test.sign_up_as_anon().await;

  let uid = test.user_manager.get_anon_user().await.unwrap().id;
  let mut db_conn = test.user_manager.db_connection(uid).unwrap();

  let workspace_id = Uuid::new_v4();
  let person_id = Uuid::new_v4();

  // Test 1: Create (Insert) - Test upsert_mentionable_person
  let person = MentionablePersonTable::new(
    person_id,
    workspace_id,
    "John Doe".to_string(),
    "john@example.com".to_string(),
    MentionablePersonType::WorkspaceMember,
    Some("https://example.com/avatar.jpg".to_string()),
    None,
    None,
    Some("Software Engineer".to_string()),
    true,
    None,
  );

  let result = upsert_mentionable_person(&mut db_conn, &person);
  assert!(
    result.is_ok(),
    "Failed to insert mentionable person: {:?}",
    result
  );
  drop(db_conn);

  // Test 2: Read - Test select_mentionable_person
  let mut db_conn = test.user_manager.db_connection(uid).unwrap();
  let selected_person = select_mentionable_person(
    &mut db_conn,
    &workspace_id.to_string(),
    &person_id.to_string(),
  )
  .unwrap()
  .unwrap();
  drop(db_conn);

  assert_eq!(selected_person.name, "John Doe");
  assert_eq!(selected_person.email, "john@example.com");
  assert_eq!(
    selected_person.role,
    MentionablePersonType::WorkspaceMember as i32
  );
  assert_eq!(
    selected_person.avatar_url,
    Some("https://example.com/avatar.jpg".to_string())
  );
  assert_eq!(
    selected_person.description,
    Some("Software Engineer".to_string())
  );
  assert!(selected_person.invited);

  // Test 3: Update - Test update_role
  let mut db_conn = test.user_manager.db_connection(uid).unwrap();
  update_role(
    &mut db_conn,
    &workspace_id.to_string(),
    &person_id.to_string(),
    MentionablePersonType::WorkspaceGuest,
  )
  .unwrap();
  drop(db_conn);

  // Verify role was updated
  let mut db_conn = test.user_manager.db_connection(uid).unwrap();
  let updated_person = select_mentionable_person(
    &mut db_conn,
    &workspace_id.to_string(),
    &person_id.to_string(),
  )
  .unwrap()
  .unwrap();
  drop(db_conn);

  assert_eq!(
    updated_person.role,
    MentionablePersonType::WorkspaceGuest as i32
  );

  // Test 4: Update - Test update_last_mentioned_at
  let mut db_conn = test.user_manager.db_connection(uid).unwrap();
  let mentioned_time = chrono::Utc::now();
  update_last_mentioned_at(
    &mut db_conn,
    &workspace_id.to_string(),
    &person_id.to_string(),
    mentioned_time,
  )
  .unwrap();
  drop(db_conn);

  // Verify last mentioned time was updated
  let mut db_conn = test.user_manager.db_connection(uid).unwrap();
  let updated_person = select_mentionable_person(
    &mut db_conn,
    &workspace_id.to_string(),
    &person_id.to_string(),
  )
  .unwrap()
  .unwrap();
  drop(db_conn);

  assert!(updated_person.last_mentioned_at.is_some());
  let stored_time = updated_person.last_mentioned_at.unwrap();
  let expected_time = mentioned_time.naive_utc();

  // Allow for small time differences due to database operations
  let time_diff = (stored_time - expected_time).num_seconds().abs();
  assert!(
    time_diff < 5,
    "Time difference too large: {} seconds",
    time_diff
  );

  // Test 5: Upsert - Test updating existing person with upsert
  let updated_person_data = MentionablePersonTable::new(
    person_id, // Same person_id
    workspace_id,
    "John Doe Updated".to_string(),         // Updated name
    "john.updated@example.com".to_string(), // Updated email
    MentionablePersonType::Contact,         // Updated role
    Some("https://example.com/new-avatar.jpg".to_string()), // Updated avatar
    None,
    None,
    Some("Senior Software Engineer".to_string()), // Updated description
    false,                                        // Updated invited status
    None,
  );

  let mut db_conn = test.user_manager.db_connection(uid).unwrap();
  upsert_mentionable_person(&mut db_conn, &updated_person_data).unwrap();
  drop(db_conn);

  // Verify upsert worked correctly
  let mut db_conn = test.user_manager.db_connection(uid).unwrap();
  let upserted_person = select_mentionable_person(
    &mut db_conn,
    &workspace_id.to_string(),
    &person_id.to_string(),
  )
  .unwrap()
  .unwrap();
  drop(db_conn);

  assert_eq!(upserted_person.name, "John Doe Updated");
  assert_eq!(upserted_person.email, "john.updated@example.com");
  assert_eq!(upserted_person.role, MentionablePersonType::Contact as i32);
  assert_eq!(
    upserted_person.avatar_url,
    Some("https://example.com/new-avatar.jpg".to_string())
  );
  assert_eq!(
    upserted_person.description,
    Some("Senior Software Engineer".to_string())
  );
  assert!(!upserted_person.invited);

  // Test 6: Composite Primary Key - Test same person in different workspaces
  let workspace_id_2 = Uuid::new_v4();
  let person_2 = MentionablePersonTable::new(
    person_id,      // Same person_id
    workspace_id_2, // Different workspace_id
    "John Doe".to_string(),
    "john@example.com".to_string(),
    MentionablePersonType::WorkspaceMember,
    None,
    None,
    None,
    None,
    true,
    None,
  );

  let mut db_conn = test.user_manager.db_connection(uid).unwrap();
  upsert_mentionable_person(&mut db_conn, &person_2).unwrap();
  drop(db_conn);

  // Verify both can be retrieved separately
  let mut db_conn = test.user_manager.db_connection(uid).unwrap();
  let retrieved_1 = select_mentionable_person(
    &mut db_conn,
    &workspace_id.to_string(),
    &person_id.to_string(),
  )
  .unwrap()
  .unwrap();
  drop(db_conn);

  let mut db_conn = test.user_manager.db_connection(uid).unwrap();
  let retrieved_2 = select_mentionable_person(
    &mut db_conn,
    &workspace_id_2.to_string(),
    &person_id.to_string(),
  )
  .unwrap()
  .unwrap();
  drop(db_conn);

  // Verify they have different properties based on workspace
  assert_eq!(retrieved_1.role, MentionablePersonType::Contact as i32);
  assert_eq!(
    retrieved_2.role,
    MentionablePersonType::WorkspaceMember as i32
  );
  assert!(!retrieved_1.invited);
  assert!(retrieved_2.invited);

  // Test 7: Select by role - Test filtering functionality
  let db_conn = test.user_manager.db_connection(uid).unwrap();
  let contacts = select_mentionable_persons_by_role(
    db_conn,
    &workspace_id.to_string(),
    MentionablePersonType::Contact,
  )
  .unwrap();

  assert_eq!(contacts.len(), 1);
  assert_eq!(contacts[0].name, "John Doe Updated");

  let db_conn = test.user_manager.db_connection(uid).unwrap();
  let members = select_mentionable_persons_by_role(
    db_conn,
    &workspace_id_2.to_string(),
    MentionablePersonType::WorkspaceMember,
  )
  .unwrap();

  assert_eq!(members.len(), 1);
  assert_eq!(members[0].name, "John Doe");

  // Test 8: Delete - Test delete operations
  let mut db_conn = test.user_manager.db_connection(uid).unwrap();
  delete_workspace_mentionable_person(
    &mut db_conn,
    &workspace_id.to_string(),
    &person_id.to_string(),
  )
  .unwrap();
  drop(db_conn);

  // Verify person was deleted from workspace 1
  let mut db_conn = test.user_manager.db_connection(uid).unwrap();
  let deleted_person = select_mentionable_person(
    &mut db_conn,
    &workspace_id.to_string(),
    &person_id.to_string(),
  )
  .unwrap();

  assert!(deleted_person.is_none());

  // Verify person still exists in workspace 2
  let mut db_conn = test.user_manager.db_connection(uid).unwrap();
  let existing_person = select_mentionable_person(
    &mut db_conn,
    &workspace_id_2.to_string(),
    &person_id.to_string(),
  )
  .unwrap()
  .unwrap();
  drop(db_conn);

  assert_eq!(existing_person.name, "John Doe");

  // Test 9: Delete all - Test bulk delete
  let mut db_conn = test.user_manager.db_connection(uid).unwrap();
  delete_workspace_all_mentionable_persons(&mut db_conn, &workspace_id_2.to_string()).unwrap();
  drop(db_conn);

  // Verify all persons were deleted from workspace 2
  let mut db_conn = test.user_manager.db_connection(uid).unwrap();
  let all_persons =
    select_all_mentionable_persons(&mut db_conn, &workspace_id_2.to_string()).unwrap();
  assert_eq!(all_persons.len(), 0);
}
