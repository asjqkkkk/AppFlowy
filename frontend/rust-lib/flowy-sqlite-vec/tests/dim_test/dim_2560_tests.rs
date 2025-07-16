use anyhow::Result;
use flowy_ai_pub::entities::{EmbeddedChunk, EmbeddingDimension};
use flowy_sqlite_vec::db::VectorSqliteDB;
use tempfile::tempdir;
use uuid::Uuid;

#[tokio::test]
async fn test_2560_dim_basic_operations() -> Result<()> {
  // Create a temporary directory for the test database
  let temp_dir = tempdir()?;

  // Create the VectorSqliteDB
  let db = VectorSqliteDB::new(temp_dir.into_path())?;

  // Test inserting vector embeddings
  let oid = Uuid::new_v4().to_string();
  let fragments = vec![
    create_test_fragment(&oid, 0, generate_embedding_with_size(2560, 0.1)),
    create_test_fragment(&oid, 1, generate_embedding_with_size(2560, 0.2)),
    create_test_fragment(&oid, 2, generate_embedding_with_size(2560, 0.3)),
  ];
  let workspace_id = Uuid::new_v4();
  db.upsert_collabs_embeddings(
    &workspace_id.to_string(),
    &oid,
    fragments,
    EmbeddingDimension::Dim2560,
  )
  .await?;

  // Test querying fragment IDs
  let result = db
    .select_collabs_fragment_ids(&[oid.clone()], EmbeddingDimension::Dim2560)
    .await?;
  assert_eq!(result.len(), 1);
  assert!(result.contains_key(&Uuid::parse_str(&oid)?));
  assert_eq!(result.get(&Uuid::parse_str(&oid)?).unwrap().len(), 3);

  Ok(())
}

#[tokio::test]
async fn test_2560_dim_search() -> Result<()> {
  let temp_dir = tempdir()?;
  let db = VectorSqliteDB::new(temp_dir.into_path())?;

  let oid = Uuid::new_v4().to_string();
  let workspace_id = Uuid::new_v4().to_string();

  // Insert test fragments with different embeddings
  let fragments = vec![
    create_test_fragment(&oid, 0, generate_embedding_with_size(2560, 0.1)),
    create_test_fragment(&oid, 1, generate_embedding_with_size(2560, 0.5)),
    create_test_fragment(&oid, 2, generate_embedding_with_size(2560, 0.9)),
  ];

  db.upsert_collabs_embeddings(&workspace_id, &oid, fragments, EmbeddingDimension::Dim2560)
    .await?;

  // Search for similar vectors
  let query = generate_embedding_with_size(2560, 0.5);
  let results = db
    .search(
      &workspace_id,
      &[oid],
      &query,
      3,
      EmbeddingDimension::Dim2560,
    )
    .await?;

  assert_eq!(results.len(), 1);
  // The fragment with value 0.5 should be the closest match
  assert_eq!(results[0].content, "Content for fragment 1");

  Ok(())
}

#[tokio::test]
async fn test_2560_dim_delete_collab() -> Result<()> {
  let temp_dir = tempdir()?;
  let db = VectorSqliteDB::new(temp_dir.into_path())?;

  let oid = Uuid::new_v4().to_string();
  let workspace_id = Uuid::new_v4().to_string();

  // Insert test fragment
  let fragments = vec![create_test_fragment(
    &oid,
    0,
    generate_embedding_with_size(2560, 0.1),
  )];

  db.upsert_collabs_embeddings(&workspace_id, &oid, fragments, EmbeddingDimension::Dim2560)
    .await?;

  // Verify it exists
  let result = db
    .select_collabs_fragment_ids(&[oid.clone()], EmbeddingDimension::Dim2560)
    .await?;
  assert_eq!(result.len(), 1);

  // Delete the collab
  db.delete_collab(&workspace_id, &oid).await?;

  // Verify it's gone
  let result = db
    .select_collabs_fragment_ids(&[oid.clone()], EmbeddingDimension::Dim2560)
    .await?;
  assert!(result.is_empty());

  Ok(())
}

#[tokio::test]
async fn test_2560_dim_select_embedded_content() -> Result<()> {
  let temp_dir = tempdir()?;
  let db = VectorSqliteDB::new(temp_dir.into_path())?;

  let workspace_id = Uuid::new_v4().to_string();
  let oid1 = Uuid::new_v4().to_string();
  let oid2 = Uuid::new_v4().to_string();

  // Insert test fragments for two objects
  db.upsert_collabs_embeddings(
    &workspace_id,
    &oid1,
    vec![create_test_fragment(
      &oid1,
      0,
      generate_embedding_with_size(2560, 0.1),
    )],
    EmbeddingDimension::Dim2560,
  )
  .await?;

  db.upsert_collabs_embeddings(
    &workspace_id,
    &oid2,
    vec![create_test_fragment(
      &oid2,
      0,
      generate_embedding_with_size(2560, 0.2),
    )],
    EmbeddingDimension::Dim2560,
  )
  .await?;

  // Select all content
  let content = db
    .select_all_embedded_content(&workspace_id, &[], 10, EmbeddingDimension::Dim2560)
    .await?;
  assert_eq!(content.len(), 2);

  // Select content for specific object
  let content = db
    .select_all_embedded_content(
      &workspace_id,
      &[oid1.clone()],
      10,
      EmbeddingDimension::Dim2560,
    )
    .await?;
  assert_eq!(content.len(), 1);
  assert_eq!(content[0].object_id, oid1);

  Ok(())
}

#[tokio::test]
async fn test_2560_dim_select_embedded_documents() -> Result<()> {
  let temp_dir = tempdir()?;
  let db = VectorSqliteDB::new(temp_dir.into_path())?;

  let workspace_id = Uuid::new_v4().to_string();
  let oid = Uuid::new_v4().to_string();

  // Insert multiple fragments for one object
  let fragments = vec![
    create_test_fragment(&oid, 0, generate_embedding_with_size(2560, 0.1)),
    create_test_fragment(&oid, 1, generate_embedding_with_size(2560, 0.2)),
  ];

  db.upsert_collabs_embeddings(&workspace_id, &oid, fragments, EmbeddingDimension::Dim2560)
    .await?;

  // Select documents
  let docs = db
    .select_all_embedded_documents(&workspace_id, &[], EmbeddingDimension::Dim2560)
    .await?;
  assert_eq!(docs.len(), 1);
  assert_eq!(docs[0].object_id, oid);
  assert_eq!(docs[0].fragments.len(), 2);

  // Verify embeddings are correct size
  for fragment in &docs[0].fragments {
    assert_eq!(fragment.embeddings.len(), 2560);
  }

  Ok(())
}

#[tokio::test]
async fn test_2560_dim_mixed_dimensions() -> Result<()> {
  let temp_dir = tempdir()?;
  let db = VectorSqliteDB::new(temp_dir.into_path())?;

  let workspace_id = Uuid::new_v4().to_string();
  let oid = Uuid::new_v4().to_string();

  // Insert 768-dim fragment
  let fragments_768 = vec![create_test_fragment(
    &oid,
    0,
    generate_embedding_with_size(768, 0.1),
  )];
  db.upsert_collabs_embeddings(
    &workspace_id,
    &oid,
    fragments_768,
    EmbeddingDimension::Dim768,
  )
  .await?;

  // Insert 2560-dim fragment with different index
  let fragments_2560 = vec![create_test_fragment(
    &oid,
    1,
    generate_embedding_with_size(2560, 0.2),
  )];
  db.upsert_collabs_embeddings(
    &workspace_id,
    &oid,
    fragments_2560,
    EmbeddingDimension::Dim2560,
  )
  .await?;

  // Verify both dimensions exist separately
  let result_768 = db
    .select_collabs_fragment_ids(&[oid.clone()], EmbeddingDimension::Dim768)
    .await?;
  assert_eq!(result_768.get(&Uuid::parse_str(&oid)?).unwrap().len(), 1);

  let result_2560 = db
    .select_collabs_fragment_ids(&[oid.clone()], EmbeddingDimension::Dim2560)
    .await?;
  assert_eq!(result_2560.get(&Uuid::parse_str(&oid)?).unwrap().len(), 1);

  // Test searching in each dimension
  let search_768 = db
    .search(
      &workspace_id,
      &[],
      &generate_embedding_with_size(768, 0.1),
      1,
      EmbeddingDimension::Dim768,
    )
    .await?;
  assert_eq!(search_768.len(), 1);
  assert_eq!(search_768[0].content, "Content for fragment 0");

  let search_2560 = db
    .search(
      &workspace_id,
      &[],
      &generate_embedding_with_size(2560, 0.2),
      1,
      EmbeddingDimension::Dim2560,
    )
    .await?;
  assert_eq!(search_2560.len(), 1);
  assert_eq!(search_2560[0].content, "Content for fragment 1");

  Ok(())
}

fn generate_embedding_with_size(size: usize, value: f32) -> Vec<f32> {
  vec![value; size]
}

fn create_test_fragment(oid: &str, index: i32, embeddings: Vec<f32>) -> EmbeddedChunk {
  let fragment_id = format!("fragment_{}", index);
  let dimension = embeddings.len();

  EmbeddedChunk {
    fragment_id,
    object_id: oid.to_string(),
    content_type: 1,
    content: Some(format!("Content for fragment {}", index)),
    metadata: Some(format!("Metadata for fragment {}", index)),
    fragment_index: index,
    embeddings: Some(embeddings),
    dimension,
  }
}
