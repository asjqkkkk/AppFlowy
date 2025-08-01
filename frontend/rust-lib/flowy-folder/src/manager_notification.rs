use crate::entities::MentionablePersonPB;
use crate::manager::FolderManager;
use crate::notification::{FolderNotification, folder_notification_builder};
use client_api::entity::workspace_dto::RecentViewItem;
use client_api::entity::{
  MentionablePersonListChangedBody, SectionChangedBody, WorkspaceNotification,
};
use flowy_error::FlowyResult;
use flowy_folder_pub::sql::mentionable_person_sql::{
  select_mentionable_person, update_last_mentioned_at, update_mentionable_person,
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
      WorkspaceNotification::MentionablePersonListChanged { data } => {
        self.handle_member_list_changed_notification(data).await
      },
      _ => Ok(()),
    }
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
    self.send_update_recent_views_notification().await;
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
    data: MentionablePersonListChangedBody,
  ) -> FlowyResult<()> {
    let uid = self.user.user_id()?;
    let mut db = self.user.sqlite_connection(uid)?;

    match data {
      MentionablePersonListChangedBody::UpdateMemberRole {
        user_uuid,
        email: _,
        role,
      } => {
        // Update the role for the mentionable person if they exist
        if let Some(mut person) = select_mentionable_person(&mut db, &user_uuid.to_string())? {
          person.role = role as i32;
          update_mentionable_person(&mut db, &person)?;
          let updated_person = person.to_entity().into();
          self
            .send_update_mentionable_person_notification(updated_person)
            .await;
        } else {
          debug!(
            "Mentionable person not found for role update, ignoring: {}",
            user_uuid
          );
        }
      },
      MentionablePersonListChangedBody::PageMention {
        user_uuid,
        view_id: _,
        mentioned_at,
      } => {
        if let Some(person) = select_mentionable_person(&mut db, &user_uuid.to_string())? {
          update_last_mentioned_at(&mut db, &user_uuid.to_string(), mentioned_at)?;
          let updated_person = person.to_entity().into();
          self
            .send_update_mentionable_person_notification(updated_person)
            .await;
        } else {
          debug!(
            "Mentionable person not found for mention update, ignoring: {}",
            user_uuid
          );
        }
      },
    }

    Ok(())
  }

  pub(crate) async fn send_update_recent_views_notification(&self) {
    if let Ok(workspace_id) = self.user.workspace_id() {
      folder_notification_builder(
        workspace_id.to_string(),
        FolderNotification::DidUpdateRecentViews,
      )
      .send();
    }
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
