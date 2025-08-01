use chrono::{DateTime, Utc};
use client_api::entity::{MentionablePersonType, MentionablePersonWithLastMentionedTime};
use diesel::{RunQueryDsl, delete, insert_into, update};
use flowy_error::FlowyResult;
use flowy_sqlite::schema::mentionable_person;
use flowy_sqlite::schema::mentionable_person::dsl;
use flowy_sqlite::{DBConnection, ExpressionMethods, SqliteConnection, prelude::*};
use uuid::Uuid;

#[derive(Queryable, Insertable, AsChangeset, Debug, Clone)]
#[diesel(table_name = mentionable_person)]
#[diesel(primary_key(person_id))]
pub struct MentionablePersonTable {
  pub person_id: String,
  pub workspace_id: String,
  pub name: String,
  pub email: String,
  pub role: i32,
  pub avatar_url: Option<String>,
  pub cover_image_url: Option<String>,
  pub custom_image_url: Option<String>,
  pub description: Option<String>,
  pub invited: bool,
  pub last_mentioned_at: Option<chrono::NaiveDateTime>,
}

impl MentionablePersonTable {
  #[allow(clippy::too_many_arguments)]
  pub fn new(
    person_id: Uuid,
    workspace_id: Uuid,
    name: String,
    email: String,
    role: MentionablePersonType,
    avatar_url: Option<String>,
    cover_image_url: Option<String>,
    custom_image_url: Option<String>,
    description: Option<String>,
    invited: bool,
    last_mentioned_at: Option<DateTime<Utc>>,
  ) -> Self {
    Self {
      person_id: person_id.to_string(),
      workspace_id: workspace_id.to_string(),
      name,
      email,
      role: role as i32,
      avatar_url,
      cover_image_url,
      custom_image_url,
      description,
      invited,
      last_mentioned_at: last_mentioned_at.map(|dt| dt.naive_utc()),
    }
  }

  pub fn from_entity(person: MentionablePersonWithLastMentionedTime, workspace_id: Uuid) -> Self {
    Self {
      person_id: person.person_id.to_string(),
      workspace_id: workspace_id.to_string(),
      name: person.name,
      email: person.email,
      role: person.role as i32,
      avatar_url: person.avatar_url,
      cover_image_url: person.cover_image_url,
      custom_image_url: person.custom_image_url,
      description: person.description,
      invited: person.invited,
      last_mentioned_at: person.last_mentioned_at.map(|dt| dt.naive_utc()),
    }
  }

  pub fn to_entity(&self) -> MentionablePersonWithLastMentionedTime {
    MentionablePersonWithLastMentionedTime {
      person_id: Uuid::parse_str(&self.person_id).unwrap_or_default(),
      name: self.name.clone(),
      email: self.email.clone(),
      role: match self.role {
        0 => MentionablePersonType::WorkspaceMember,
        1 => MentionablePersonType::WorkspaceGuest,
        2 => MentionablePersonType::Contact,
        _ => MentionablePersonType::WorkspaceMember, // Default fallback
      },
      avatar_url: self.avatar_url.clone(),
      cover_image_url: self.cover_image_url.clone(),
      custom_image_url: self.custom_image_url.clone(),
      description: self.description.clone(),
      invited: self.invited,
      last_mentioned_at: self
        .last_mentioned_at
        .map(|dt| DateTime::from_naive_utc_and_offset(dt, Utc)),
    }
  }
}

/// Insert a new mentionable person
pub fn insert_mentionable_person(
  conn: &mut SqliteConnection,
  person: &MentionablePersonTable,
) -> FlowyResult<()> {
  insert_into(mentionable_person::table)
    .values(person)
    .execute(conn)?;

  Ok(())
}

/// Update the last mentioned time for a person
pub fn update_last_mentioned_at(
  conn: &mut SqliteConnection,
  workspace_id: &str,
  person_id: &str,
  last_mentioned_at: DateTime<Utc>,
) -> FlowyResult<()> {
  update(mentionable_person::table.filter(mentionable_person::person_id.eq(person_id)))
    .filter(mentionable_person::workspace_id.eq(workspace_id))
    .set(mentionable_person::last_mentioned_at.eq(last_mentioned_at.naive_utc()))
    .execute(conn)?;

  Ok(())
}

pub fn delete_workspace_mentionable_person(
  conn: &mut SqliteConnection,
  workspace_id: &str,
) -> FlowyResult<()> {
  delete(mentionable_person::table.filter(mentionable_person::workspace_id.eq(workspace_id)))
    .execute(conn)?;

  Ok(())
}

/// Update a person's information
pub fn update_mentionable_person(
  conn: &mut SqliteConnection,
  workspace_id: &str,
  person: &MentionablePersonTable,
) -> FlowyResult<()> {
  update(mentionable_person::table.filter(mentionable_person::person_id.eq(&person.person_id)))
    .filter(mentionable_person::workspace_id.eq(workspace_id))
    .set((
      mentionable_person::workspace_id.eq(&person.workspace_id),
      mentionable_person::name.eq(&person.name),
      mentionable_person::email.eq(&person.email),
      mentionable_person::role.eq(&person.role),
      mentionable_person::avatar_url.eq(&person.avatar_url),
      mentionable_person::cover_image_url.eq(&person.cover_image_url),
      mentionable_person::custom_image_url.eq(&person.custom_image_url),
      mentionable_person::description.eq(&person.description),
      mentionable_person::invited.eq(&person.invited),
      mentionable_person::last_mentioned_at.eq(&person.last_mentioned_at),
    ))
    .execute(conn)?;

  Ok(())
}

/// Select a mentionable person by UUID
pub fn select_mentionable_person(
  conn: &mut SqliteConnection,
  workspace_id: &str,
  uuid: &str,
) -> FlowyResult<Option<MentionablePersonTable>> {
  let person = dsl::mentionable_person
    .filter(mentionable_person::person_id.eq(uuid))
    .filter(mentionable_person::workspace_id.eq(workspace_id))
    .first::<MentionablePersonTable>(conn)
    .optional()?;

  Ok(person)
}

/// Select all mentionable persons for a workspace
pub fn select_all_mentionable_persons(
  mut conn: DBConnection,
  workspace_id: &str,
) -> FlowyResult<Vec<MentionablePersonTable>> {
  let persons = dsl::mentionable_person
    .filter(mentionable_person::workspace_id.eq(workspace_id))
    .order(mentionable_person::name.asc())
    .load::<MentionablePersonTable>(&mut conn)?;

  Ok(persons)
}

/// Select mentionable persons by role for a workspace
pub fn select_mentionable_persons_by_role(
  mut conn: DBConnection,
  workspace_id: &str,
  role: MentionablePersonType,
) -> FlowyResult<Vec<MentionablePersonTable>> {
  let persons = dsl::mentionable_person
    .filter(mentionable_person::workspace_id.eq(workspace_id))
    .filter(mentionable_person::role.eq(role as i32))
    .order(mentionable_person::name.asc())
    .load::<MentionablePersonTable>(&mut conn)?;

  Ok(persons)
}

/// Select mentionable persons ordered by last mentioned time (most recent first) for a workspace
pub fn select_mentionable_persons_by_last_mentioned(
  mut conn: DBConnection,
  workspace_id: &str,
  limit: Option<u32>,
  offset: Option<u32>,
) -> FlowyResult<Vec<MentionablePersonTable>> {
  let mut query = dsl::mentionable_person
    .filter(mentionable_person::workspace_id.eq(workspace_id))
    .filter(mentionable_person::last_mentioned_at.is_not_null())
    .order(mentionable_person::last_mentioned_at.desc())
    .into_boxed();

  if let Some(offset_value) = offset {
    query = query.offset(offset_value as i64);
  }

  if let Some(limit_value) = limit {
    query = query.limit(limit_value as i64);
  }

  let persons = query.load::<MentionablePersonTable>(&mut conn)?;
  Ok(persons)
}

/// Batch insert multiple mentionable persons from entities
pub fn insert_mentionable_persons_from_entities(
  conn: &mut SqliteConnection,
  workspace_id: Uuid,
  persons: Vec<MentionablePersonWithLastMentionedTime>,
) -> FlowyResult<()> {
  for person in persons {
    let table_person = MentionablePersonTable::from_entity(person, workspace_id);
    insert_mentionable_person(conn, &table_person)?;
  }

  Ok(())
}
