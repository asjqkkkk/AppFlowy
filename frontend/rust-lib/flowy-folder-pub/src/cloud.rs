use crate::entities::PublishPayload;
pub use anyhow::Error;
use client_api::entity::workspace_dto::RecentViewItem;
use client_api::entity::{
  CreateImportTaskType, MentionablePerson, MentionablePersons, PageMentionUpdate, PublishInfo,
  guest_dto::{
    RevokeSharedViewAccessRequest, ShareViewWithGuestRequest, SharedViewDetails, SharedViews,
  },
  workspace_dto::PublishInfoView,
};
use collab::entity::EncodedCollab;
use collab_entity::CollabType;
pub use collab_folder::{Folder, FolderData, Workspace};
use flowy_error::FlowyError;
use lib_infra::async_trait::async_trait;
use uuid::Uuid;

/// [FolderCloudService] represents the cloud service for folder.
#[async_trait]
pub trait FolderCloudService: Send + Sync + 'static {
  async fn get_folder_snapshots(
    &self,
    workspace_id: &str,
    limit: usize,
  ) -> Result<Vec<FolderSnapshot>, FlowyError>;

  async fn get_folder_doc_state(
    &self,
    workspace_id: &Uuid,
    uid: i64,
    collab_type: CollabType,
    object_id: &Uuid,
  ) -> Result<Vec<u8>, FlowyError>;

  async fn full_sync_collab_object(
    &self,
    workspace_id: &Uuid,
    params: FullSyncCollabParams,
  ) -> Result<(), FlowyError>;

  async fn batch_create_folder_collab_objects(
    &self,
    workspace_id: &Uuid,
    objects: Vec<FolderCollabParams>,
  ) -> Result<(), FlowyError>;

  fn service_name(&self) -> String;

  async fn publish_view(
    &self,
    workspace_id: &Uuid,
    payload: Vec<PublishPayload>,
  ) -> Result<(), FlowyError>;

  async fn unpublish_views(
    &self,
    workspace_id: &Uuid,
    view_ids: Vec<Uuid>,
  ) -> Result<(), FlowyError>;

  async fn get_publish_info(&self, view_id: &Uuid) -> Result<PublishInfo, FlowyError>;

  async fn set_publish_name(
    &self,
    workspace_id: &Uuid,
    view_id: Uuid,
    new_name: String,
  ) -> Result<(), FlowyError>;

  async fn set_publish_namespace(
    &self,
    workspace_id: &Uuid,
    new_namespace: String,
  ) -> Result<(), FlowyError>;

  async fn list_published_views(
    &self,
    workspace_id: &Uuid,
  ) -> Result<Vec<PublishInfoView>, FlowyError>;

  async fn get_default_published_view_info(
    &self,
    workspace_id: &Uuid,
  ) -> Result<PublishInfo, FlowyError>;

  async fn set_default_published_view(
    &self,
    workspace_id: &Uuid,
    view_id: uuid::Uuid,
  ) -> Result<(), FlowyError>;

  async fn remove_default_published_view(&self, workspace_id: &Uuid) -> Result<(), FlowyError>;

  async fn get_publish_namespace(&self, workspace_id: &Uuid) -> Result<String, FlowyError>;

  async fn import_zip(
    &self,
    file_path: &str,
    task_type: CreateImportTaskType,
  ) -> Result<(), FlowyError>;

  /// Share a page with a user (member or guest)
  async fn share_page_with_user(
    &self,
    workspace_id: &Uuid,
    params: ShareViewWithGuestRequest,
  ) -> Result<(), FlowyError>;

  /// Revoke access to a page for a user (member or guest)
  async fn revoke_shared_page_access(
    &self,
    workspace_id: &Uuid,
    view_id: &Uuid,
    params: RevokeSharedViewAccessRequest,
  ) -> Result<(), FlowyError>;

  /// Get the shared members/guests of a page
  async fn get_shared_page_details(
    &self,
    workspace_id: &Uuid,
    view_id: &Uuid,
    parent_view_ids: Vec<Uuid>,
  ) -> Result<SharedViewDetails, FlowyError>;

  /// Get the shared views of a workspace
  async fn get_shared_views(&self, workspace_id: &Uuid) -> Result<SharedViews, FlowyError>;

  /// Get the mentionable persons in a workspace
  async fn get_workspace_mentionable_persons(
    &self,
    workspace_id: &Uuid,
  ) -> Result<MentionablePersons, FlowyError>;

  async fn get_workspace_mentionable_person(
    &self,
    workspace_id: &Uuid,
    person_id: &Uuid,
  ) -> Result<MentionablePerson, FlowyError>;

  /// Update the mentionable persons in a page(with access)
  async fn update_page_mention(
    &self,
    workspace_id: &Uuid,
    view_id: &Uuid,
    page_mention: &PageMentionUpdate,
  ) -> Result<(), FlowyError>;

  async fn get_recent_views(
    &self,
    workspace_id: &Uuid,
    limit: u32,
    offset: u32,
  ) -> Result<Vec<RecentViewItem>, FlowyError>;

  async fn add_recent_views(
    &self,
    workspace_id: &Uuid,
    view_ids: Vec<Uuid>,
  ) -> Result<(), FlowyError>;

  async fn delete_recent_views(
    &self,
    workspace_id: &Uuid,
    view_ids: Vec<Uuid>,
  ) -> Result<(), FlowyError>;
}

#[derive(Debug)]
pub struct FolderCollabParams {
  pub object_id: Uuid,
  pub encoded_collab_v1: Vec<u8>,
  pub collab_type: CollabType,
}

#[derive(Debug)]
pub struct FullSyncCollabParams {
  pub object_id: Uuid,
  pub encoded_collab: EncodedCollab,
  pub collab_type: CollabType,
}

pub struct FolderSnapshot {
  pub snapshot_id: i64,
  pub database_id: String,
  pub data: Vec<u8>,
  pub created_at: i64,
}

pub fn gen_workspace_id() -> Uuid {
  uuid::Uuid::new_v4()
}

pub fn gen_view_id() -> Uuid {
  uuid::Uuid::new_v4()
}

#[derive(Debug)]
pub struct WorkspaceRecord {
  pub id: String,
  pub name: String,
  pub created_at: i64,
}
