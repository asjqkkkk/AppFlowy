use crate::entities::MentionablePersonPB;
use crate::manager::FolderManager;
use crate::notification::{FolderNotification, folder_notification_builder};
use chrono::{DateTime, Utc};
use client_api::entity::workspace_dto::RecentViewItem;
use client_api::entity::{
  AFRole, MentionablePersonType, SectionChangedBody, WorkspaceNotification,
};
use flowy_error::FlowyResult;
use flowy_folder_pub::sql::mentionable_person_sql::{
  MentionablePersonTable, delete_workspace_mentionable_person, select_mentionable_person,
  update_last_mentioned_at, update_role, upsert_mentionable_person,
};
use flowy_folder_pub::sql::recent_view_sql::{delete_user_recent_views, upsert_user_recent_views};
use tracing::{debug, info};
use uuid::Uuid;

impl FolderManager {
  pub async fn handle_notification(&self, notification: WorkspaceNotification) -> FlowyResult<()> {
    debug!("folder handle workspace notification: {:?}", notification);
    match notification {
      WorkspaceNotification::SectionChanged { data } => match data {
        SectionChangedBody::AddRecentViews { items } => {
          self.handle_recent_section_notification(items, vec![]).await
        },
        SectionChangedBody::RemoveRecentViews { ids } => {
          self.handle_recent_section_notification(vec![], ids).await
        },
      },
      WorkspaceNotification::ShareViewsChanged { view_id, emails } => {
        self
          .handle_share_views_changed_notification(view_id, emails)
          .await
      },
      WorkspaceNotification::MentionablePersonListChangedUpdateMemberRole {
        user_uuid,
        email: _,
        role,
      } => {
        self
          .handle_member_list_changed_notification(user_uuid, None, Some(role))
          .await
      },
      WorkspaceNotification::MentionablePersonListChangedPageMention {
        user_uuid,
        view_id: _,
        mentioned_at,
      } => {
        self
          .handle_member_list_changed_notification(user_uuid, Some(mentioned_at), None)
          .await
      },
      WorkspaceNotification::MentionablePersonListChangedNewMember { user_uuid } => {
        self.fetch_single_mentionable_person(user_uuid).await
      },
      WorkspaceNotification::MentionablePersonListChangedRemovedMember { user_uuid } => {
        self.delete_mentionable_person(user_uuid)
      },
      _ => Ok(()),
    }
  }

  async fn fetch_single_mentionable_person(&self, user_uuid: Uuid) -> FlowyResult<()> {
    let workspace_id = self.user.workspace_id()?;
    if let Some(cloud_service) = self.cloud_service.upgrade() {
      if let Ok(person) = cloud_service
        .get_workspace_mentionable_person(&workspace_id, &user_uuid)
        .await
      {
        let uid = self.user.user_id()?;
        let mut db = self.user.sqlite_connection(uid)?;
        let row = MentionablePersonTable::from_mention_person(person, workspace_id);
        upsert_mentionable_person(&mut db, &row)?;
        self
          .send_update_mentionable_person_notification(row.to_entity().into())
          .await;
      }
    }
    Ok(())
  }

  fn delete_mentionable_person(&self, user_uuid: Uuid) -> FlowyResult<()> {
    let uid = self.user.user_id()?;
    let workspace_id = self.user.workspace_id()?.to_string();
    let mut db = self.user.sqlite_connection(uid)?;
    delete_workspace_mentionable_person(&mut db, &workspace_id, &user_uuid.to_string())?;
    Ok(())
  }

  async fn handle_recent_section_notification(
    &self,
    inserted_items: Vec<RecentViewItem>,
    removed_ids: Vec<Uuid>,
  ) -> FlowyResult<()> {
    if inserted_items.is_empty() && removed_ids.is_empty() {
      return Ok(());
    }

    let uid = self.user.user_id()?;
    let workspace_id = self.user.workspace_id()?.to_string();
    let mut db = self.user.sqlite_connection(uid)?;
    upsert_user_recent_views(&mut db, uid, &workspace_id, inserted_items)?;
    delete_user_recent_views(&mut db, uid, &workspace_id, removed_ids)?;
    Ok(())
  }

  async fn handle_share_views_changed_notification(
    &self,
    view_id: Uuid,
    emails: Vec<String>,
  ) -> FlowyResult<()> {
    info!(
      "Shared views changed for view: {}, emails: {:?}",
      view_id, emails
    );
    let _ = self.get_shared_pages(true).await?;
    Ok(())
  }

  async fn handle_member_list_changed_notification(
    &self,
    user_uuid: Uuid,
    mentioned_at: Option<DateTime<Utc>>,
    role: Option<AFRole>,
  ) -> FlowyResult<()> {
    let uid = self.user.user_id()?;
    let workspace_id = self.user.workspace_id()?.to_string();
    let mut db = self.user.sqlite_connection(uid)?;
    let mut updated_person = None;

    // Handle role update
    if let Some(role) = role {
      if let Some(person) =
        select_mentionable_person(&mut db, &workspace_id, &user_uuid.to_string())?
      {
        update_role(
          &mut db,
          &workspace_id,
          &user_uuid.to_string(),
          MentionablePersonType::from(role),
        )?;
        updated_person = Some(person.to_entity().into());
      } else {
        debug!(
          "Mentionable person not found for role update, ignoring: {}",
          user_uuid
        );
      }
    }

    // Handle mention update
    if let Some(mentioned_at) = mentioned_at {
      if let Some(person) =
        select_mentionable_person(&mut db, &workspace_id, &user_uuid.to_string())?
      {
        update_last_mentioned_at(&mut db, &workspace_id, &user_uuid.to_string(), mentioned_at)?;
        updated_person = Some(person.to_entity().into());
      } else {
        debug!(
          "Mentionable person not found for mention update, ignoring: {}",
          user_uuid
        );
      }
    }

    // Send notification only once if we have an updated person
    if let Some(person) = updated_person {
      self
        .send_update_mentionable_person_notification(person)
        .await;
    }

    Ok(())
  }

  pub(crate) async fn send_update_mentionable_person_notification(
    &self,
    person: MentionablePersonPB,
  ) {
    if let Ok(workspace_id) = self.user.workspace_id() {
      folder_notification_builder(
        workspace_id.to_string(),
        FolderNotification::DidUpdateMentionablePerson,
      )
      .payload(person)
      .send();
    }
  }
}
