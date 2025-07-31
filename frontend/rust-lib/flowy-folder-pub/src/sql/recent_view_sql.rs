use client_api::entity::workspace_dto::RecentViewItem;
use diesel::{RunQueryDsl, delete, insert_into};
use flowy_error::FlowyResult;
use flowy_sqlite::schema::user_recent_view;
use flowy_sqlite::schema::user_recent_view::dsl;
use flowy_sqlite::{DBConnection, ExpressionMethods, SqliteConnection, prelude::*};

#[derive(Queryable, Insertable, AsChangeset, Debug, Clone)]
#[diesel(table_name = user_recent_view)]
#[diesel(primary_key(view_id, uid, workspace_id))]
pub struct UserRecentViewTable {
  pub view_id: String,
  pub view_at: chrono::NaiveDateTime,
  pub uid: i64,
  pub workspace_id: String,
}

impl UserRecentViewTable {
  pub fn new(view_id: String, uid: i64, workspace_id: String) -> Self {
    Self {
      view_id,
      view_at: chrono::Utc::now().naive_utc(),
      uid,
      workspace_id,
    }
  }
}

/// Upsert a recent view entry. If the view already exists for the user and workspace, updates the timestamp.
pub fn upsert_user_recent_view(
  conn: &mut SqliteConnection,
  recent_view: &UserRecentViewTable,
) -> FlowyResult<()> {
  insert_into(user_recent_view::table)
    .values(recent_view)
    .on_conflict((
      user_recent_view::view_id,
      user_recent_view::uid,
      user_recent_view::workspace_id,
    ))
    .do_update()
    .set(user_recent_view::view_at.eq(recent_view.view_at))
    .execute(conn)?;

  Ok(())
}

/// Delete a specific recent view entry for a user and workspace
pub fn delete_user_recent_views<T: ToString>(
  conn: &mut SqliteConnection,
  uid: i64,
  workspace_id: &str,
  view_ids: Vec<T>,
) -> FlowyResult<()> {
  for view_id in view_ids {
    let view_id = view_id.to_string();
    delete(
      user_recent_view::table
        .filter(user_recent_view::view_id.eq(view_id))
        .filter(user_recent_view::uid.eq(uid))
        .filter(user_recent_view::workspace_id.eq(workspace_id)),
    )
    .execute(conn)?;
  }

  Ok(())
}

pub fn select_latest_recent_view(
  mut conn: DBConnection,
  uid: i64,
  workspace_id: &str,
) -> FlowyResult<Option<UserRecentViewTable>> {
  let recent_view = dsl::user_recent_view
    .filter(user_recent_view::uid.eq(uid))
    .filter(user_recent_view::workspace_id.eq(workspace_id))
    .order(user_recent_view::view_at.desc())
    .first::<UserRecentViewTable>(&mut conn)
    .optional()?;

  Ok(recent_view)
}

/// Select recent views for a user in a specific workspace ordered by view_at desc with optional limit and offset
pub fn select_user_recent_views(
  mut conn: DBConnection,
  uid: i64,
  workspace_id: &str,
  limit: Option<u32>,
  offset: Option<u32>,
) -> FlowyResult<Vec<UserRecentViewTable>> {
  let mut query = dsl::user_recent_view
    .filter(user_recent_view::uid.eq(uid))
    .filter(user_recent_view::workspace_id.eq(workspace_id))
    .order(user_recent_view::view_at.desc())
    .into_boxed();

  if let Some(offset_value) = offset {
    query = query.offset(offset_value as i64);
  }

  if let Some(limit_value) = limit {
    query = query.limit(limit_value as i64);
  }

  let recent_views = query.load::<UserRecentViewTable>(&mut conn)?;
  Ok(recent_views)
}

/// Select a specific recent view entry for a user in a specific workspace
pub fn select_user_recent_view(
  mut conn: DBConnection,
  view_id: &str,
  uid: i64,
  workspace_id: &str,
) -> FlowyResult<UserRecentViewTable> {
  let recent_view = dsl::user_recent_view
    .filter(user_recent_view::view_id.eq(view_id))
    .filter(user_recent_view::uid.eq(uid))
    .filter(user_recent_view::workspace_id.eq(workspace_id))
    .first::<UserRecentViewTable>(&mut conn)?;

  Ok(recent_view)
}

/// Batch upsert multiple recent view entries for a specific workspace
pub fn upsert_user_recent_views(
  conn: &mut SqliteConnection,
  uid: i64,
  workspace_id: &str,
  items: Vec<RecentViewItem>,
) -> FlowyResult<Vec<UserRecentViewTable>> {
  if items.is_empty() {
    return Ok(vec![]);
  }

  let recent_views = items
    .into_iter()
    .map(|item| UserRecentViewTable {
      view_id: item.object_id.to_string(),
      view_at: item.viewed_at.naive_utc(),
      uid,
      workspace_id: workspace_id.to_string(),
    })
    .collect::<Vec<_>>();
  for recent_view in &recent_views {
    upsert_user_recent_view(conn, recent_view)?;
  }
  Ok(recent_views)
}
