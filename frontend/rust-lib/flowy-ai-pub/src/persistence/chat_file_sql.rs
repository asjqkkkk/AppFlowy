use flowy_error::{FlowyError, FlowyResult};
use flowy_sqlite::{
  DBConnection, ExpressionMethods, Identifiable, Insertable, OptionalExtension, QueryResult,
  Queryable, diesel, insert_into,
  query_dsl::*,
  schema::{chat_local_file, chat_local_file::dsl},
  upsert::excluded,
};
use uuid::Uuid;

#[derive(Queryable, Insertable, Identifiable, Debug, Clone)]
#[diesel(table_name = chat_local_file)]
#[diesel(primary_key(file_id))]
pub struct ChatLocalFileTable {
  pub file_id: String,
  pub chat_id: String,
  pub file_path: String,
  pub file_content: String,
}

impl ChatLocalFileTable {
  pub fn new(file_id: String, chat_id: String, file_path: String, file_content: String) -> Self {
    Self {
      file_id,
      chat_id,
      file_path,
      file_content,
    }
  }

  /// Create a new ChatLocalFileTable with an auto-generated UUID
  pub fn new_with_uuid(chat_id: String, file_path: String, file_content: String) -> Self {
    Self {
      file_id: Uuid::new_v4().to_string(),
      chat_id,
      file_path,
      file_content,
    }
  }
}

/// Insert or update a chat local file
pub fn upsert_chat_local_file(
  mut conn: DBConnection,
  chat_file: &ChatLocalFileTable,
) -> FlowyResult<()> {
  insert_into(chat_local_file::table)
    .values(chat_file)
    .on_conflict(chat_local_file::file_id)
    .do_update()
    .set((
      chat_local_file::chat_id.eq(excluded(chat_local_file::chat_id)),
      chat_local_file::file_path.eq(excluded(chat_local_file::file_path)),
      chat_local_file::file_content.eq(excluded(chat_local_file::file_content)),
    ))
    .execute(&mut *conn)?;

  Ok(())
}

/// Insert or update multiple chat local files
pub fn upsert_chat_local_files(
  mut conn: DBConnection,
  chat_files: &[ChatLocalFileTable],
) -> FlowyResult<()> {
  conn.immediate_transaction(|conn| {
    for file in chat_files {
      let _ = insert_into(chat_local_file::table)
        .values(file)
        .on_conflict(chat_local_file::file_id)
        .do_update()
        .set((
          chat_local_file::chat_id.eq(excluded(chat_local_file::chat_id)),
          chat_local_file::file_path.eq(excluded(chat_local_file::file_path)),
          chat_local_file::file_content.eq(excluded(chat_local_file::file_content)),
        ))
        .execute(conn)?;
    }
    Ok::<(), FlowyError>(())
  })?;

  Ok(())
}

/// Select a specific chat local file by chat_id and file_path
pub fn select_chat_local_file(
  mut conn: DBConnection,
  chat_id_val: &str,
  file_path_val: &str,
) -> QueryResult<Option<ChatLocalFileTable>> {
  let file = dsl::chat_local_file
    .filter(chat_local_file::chat_id.eq(chat_id_val))
    .filter(chat_local_file::file_path.eq(file_path_val))
    .first::<ChatLocalFileTable>(&mut *conn)
    .optional()?;
  Ok(file)
}

pub fn select_chat_file_ids(mut conn: DBConnection, chat_id_val: &str) -> FlowyResult<Vec<String>> {
  let file_ids = dsl::chat_local_file
    .filter(chat_local_file::chat_id.eq(chat_id_val))
    .select(chat_local_file::file_id)
    .load::<String>(&mut *conn)?;

  Ok(file_ids)
}

/// Delete a specific chat local file
pub fn delete_chat_local_file(
  mut conn: DBConnection,
  chat_id_val: &str,
  file_path_val: &str,
) -> FlowyResult<()> {
  diesel::delete(chat_local_file::table)
    .filter(chat_local_file::chat_id.eq(chat_id_val))
    .filter(chat_local_file::file_path.eq(file_path_val))
    .execute(&mut *conn)?;

  Ok(())
}

/// Delete all files for a specific chat
pub fn delete_all_chat_files(mut conn: DBConnection, chat_id_val: &str) -> FlowyResult<usize> {
  let deleted_count = diesel::delete(chat_local_file::table)
    .filter(chat_local_file::chat_id.eq(chat_id_val))
    .execute(&mut *conn)?;

  Ok(deleted_count)
}
