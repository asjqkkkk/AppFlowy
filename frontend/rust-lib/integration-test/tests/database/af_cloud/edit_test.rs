use collab_database::database::get_database_row_ids;
use collab_document::document::DocumentBody;
use event_integration_test::user_event::use_localhost_af_cloud;
use event_integration_test::{retry_with_backoff, EventIntegrationTest};
use flowy_database2::entities::{CellChangesetPB, FieldType, OrderObjectPositionPB};
use std::time::Duration;

#[tokio::test]
async fn af_cloud_database_create_field_and_row_test() {
  use_localhost_af_cloud().await;
  let test = EventIntegrationTest::new().await;
  let email = test.af_cloud_sign_up().await.email;
  test.wait_ws_connected().await.unwrap();
  let workspace_id = test.get_workspace_id().await;

  let grid_view = test
    .create_grid(&workspace_id.to_string(), "my grid view".to_owned(), vec![])
    .await;
  test.create_field(&grid_view.id, FieldType::Checkbox).await;
  let fields = test
    .get_all_database_fields_or_panic(&grid_view.id)
    .await
    .items;
  assert_eq!(fields.len(), 4);
  assert_eq!(fields[3].field_type, FieldType::Checkbox);

  let _ = test
    .create_row(&grid_view.id, OrderObjectPositionPB::default(), None)
    .await
    .unwrap();
  let database = test.get_database_or_panic(&grid_view.id).await;
  assert_eq!(database.rows.len(), 4);

  // same 3 client login in a new device and then check the field
  for _ in 0..3 {
    let test_2 = EventIntegrationTest::new().await;
    test_2.af_cloud_sign_in_with_email(&email).await.unwrap();
    test_2.wait_ws_connected().await.unwrap();
    tokio::time::sleep(Duration::from_secs(1)).await;

    retry_with_backoff(|| async {
      let fields = test_2.get_all_database_fields(&grid_view.id).await?.items;
      assert_eq!(fields.len(), 4);
      assert_eq!(fields[3].field_type, FieldType::Checkbox);

      let database = test_2.get_database(&grid_view.id).await?;
      if database.rows.len() != 4 {
        return Err(anyhow::anyhow!("Rows not updated yet"));
      }
      assert_eq!(database.rows.len(), 4);
      Ok(())
    })
    .await
    .unwrap();
  }
}

#[tokio::test]
async fn af_cloud_database_duplicate_row_test() {
  use_localhost_af_cloud().await;
  let test = EventIntegrationTest::new().await;
  let email = test.af_cloud_sign_up().await.email;
  test.wait_ws_connected().await.unwrap();
  let workspace_id = test.get_workspace_id().await;

  let grid_view = test
    .create_grid(&workspace_id.to_string(), "my grid view".to_owned(), vec![])
    .await;
  let database = test.get_database_or_panic(&grid_view.id).await;
  let fields = test
    .get_all_database_fields_or_panic(&grid_view.id)
    .await
    .items;
  assert_eq!(fields[0].field_type, FieldType::RichText);

  let row_id = database.rows[0].id.clone();
  let field_id = fields[0].id.clone();
  let error = test
    .update_cell(CellChangesetPB {
      view_id: grid_view.id.clone(),
      row_id: row_id.clone(),
      field_id: field_id.clone(),
      cell_changeset: "123abc".to_string(),
    })
    .await;
  assert!(error.is_none());
  let error = test.duplicate_row(&grid_view.id, &row_id).await;
  assert!(error.is_none());

  // same client login in a new device and then check the field
  let test_2 = EventIntegrationTest::new().await;
  test_2.af_cloud_sign_in_with_email(&email).await.unwrap();
  test_2.wait_ws_connected().await.unwrap();
  tokio::time::sleep(Duration::from_secs(1)).await;

  retry_with_backoff(|| async {
    let database = test_2.get_database(&grid_view.id).await?;
    if database.rows.len() != 4 {
      return Err(anyhow::anyhow!("Rows not updated yet"));
    }
    let first_row = &database.rows[0];
    let second_row = &database.rows[1];

    for row in [first_row, second_row] {
      let cell = test.get_cell(&grid_view.id, &row.id, &field_id).await;
      let s = String::from_utf8(cell.data).unwrap();
      assert_eq!(s, "123abc");
    }

    assert_eq!(database.rows.len(), 4);
    Ok(())
  })
  .await
  .unwrap();
}

#[tokio::test]
async fn af_cloud_multiple_user_edit_database_test() {
  use_localhost_af_cloud().await;
  let test = EventIntegrationTest::new().await;
  let email = test.af_cloud_sign_up().await.email;
  test.wait_ws_connected().await.unwrap();
  let workspace_id = test.get_workspace_id().await;
  let grid_view = test
    .create_grid(&workspace_id.to_string(), "my grid view".to_owned(), vec![])
    .await;

  // Verify initial state - should have 3 default rows
  let initial_database = test.get_database_or_panic(&grid_view.id).await;
  assert_eq!(initial_database.rows.len(), 3);

  let mut clients = vec![];
  for _ in 0..3 {
    let new_test = EventIntegrationTest::new().await;
    new_test.af_cloud_sign_in_with_email(&email).await.unwrap();
    retry_with_backoff(|| async {
      let _ = new_test
        .create_row(&grid_view.id, OrderObjectPositionPB::default(), None)
        .await?;
      new_test
        .create_field(&grid_view.id, FieldType::Checkbox)
        .await;
      Ok(())
    })
    .await
    .unwrap();
    clients.push(new_test);
  }

  retry_with_backoff(|| async {
    // The number of rows should be 6 (3 original + 3 new)
    let database = test.get_database(&grid_view.id).await?;
    if database.rows.len() != 6 {
      return Err(anyhow::anyhow!(
        "Expected 6 rows, got {}",
        database.rows.len()
      ));
    }

    // Verify all clients can see the same state
    for (i, client) in clients.iter().enumerate() {
      let client_database = client.get_database(&grid_view.id).await?;
      if client_database.rows.len() != 6 {
        return Err(anyhow::anyhow!(
          "Client {} sees {} rows instead of 6",
          i,
          client_database.rows.len()
        ));
      }

      let fields = client.get_all_database_fields(&grid_view.id).await?.items;
      if fields.len() != 6 {
        return Err(anyhow::anyhow!(
          "Client {} sees {} fields instead of 4",
          i,
          fields.len()
        ));
      }
      assert_eq!(fields.len(), 6);
    }

    Ok(())
  })
  .await
  .unwrap();
}

#[tokio::test]
async fn af_cloud_sync_database_without_open_it_test() {
  use_localhost_af_cloud().await;
  let test = EventIntegrationTest::new().await;
  let email = test.af_cloud_sign_up().await.email;

  let test2 = EventIntegrationTest::new().await;
  test2.af_cloud_sign_in_with_email(&email).await.unwrap();

  let workspace_id = test.get_workspace_id().await;
  let grid_view = test
    .create_grid(&workspace_id.to_string(), "my grid view".to_owned(), vec![])
    .await;
  let database = test.get_database_or_panic(&grid_view.id).await;
  let database_id = database.id.clone();
  let _ = test
    .create_row(&grid_view.id, OrderObjectPositionPB::default(), None)
    .await
    .unwrap();

  // we don't open the grid_view in test2, but the update should still be synced
  retry_with_backoff(|| async {
    let collab = test2.get_disk_collab(&database_id).await?;
    let rows = get_database_row_ids(&collab).ok_or_else(|| anyhow::anyhow!("No rows"))?;
    if rows.len() != 4 {
      return Err(anyhow::anyhow!("Expected 4 rows, got {}", rows.len()));
    }

    assert_eq!(rows.len(), 4);
    Ok(())
  })
  .await
  .unwrap();
}

#[tokio::test]
async fn af_cloud_sync_database_row_document_test() {
  use_localhost_af_cloud().await;
  let test = EventIntegrationTest::new().await;
  let email = test.af_cloud_sign_up().await.email;

  let test2 = EventIntegrationTest::new().await;
  test2.af_cloud_sign_in_with_email(&email).await.unwrap();

  let workspace_id = test.get_workspace_id().await;
  let grid_view = test
    .create_grid(&workspace_id.to_string(), "my grid view".to_owned(), vec![])
    .await;

  let rows = test.get_database(grid_view.id.as_str()).await.unwrap().rows;
  assert_eq!(rows.len(), 3);
  for (index, row) in rows.iter().enumerate() {
    test.create_row_document(&row.id, &grid_view.id).await;
    let document_id = test
      .get_row_document_id(&grid_view.id, &row.id)
      .await
      .unwrap();
    let content = format!("Hello database row document content {}", index);
    test.insert_document_text(&document_id, &content, 0).await;
  }

  retry_with_backoff(|| async {
    let database = test2.get_database(&grid_view.id).await?;
    for (index, row) in database.rows.iter().enumerate() {
      let row_document_id = test2.get_row_document_id(&grid_view.id, &row.id).await?;
      let collab = test.get_disk_collab(&row_document_id).await?;

      let txn = collab.transact();
      let document = DocumentBody::from_collab(&collab).unwrap();
      let paragraphs = document.paragraphs(txn);
      dbg!(&paragraphs);
      if paragraphs.len() != 1
        || paragraphs[0] != format!("Hello database row document content {}", index)
      {
        return Err(anyhow::anyhow!(
          "Expected document text 'Hello database row document content {}', got '{}'",
          index,
          paragraphs[0]
        ));
      }
    }

    Ok(())
  })
  .await
  .unwrap();
}
