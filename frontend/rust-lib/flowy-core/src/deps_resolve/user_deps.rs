use crate::server_layer::ServerProvider;
use collab_entity::reminder::Reminder;
use collab_folder::hierarchy_builder::ParentChildViews;
use flowy_ai_pub::cloud::WorkspaceNotification;
use flowy_database2::DatabaseManager;
use flowy_document::manager::DocumentManager;
use flowy_document::reminder::{DocumentReminder, DocumentReminderAction};
use flowy_error::{FlowyError, FlowyResult};
use flowy_folder::manager::FolderManager;
use flowy_folder_pub::cloud::Error;
use flowy_folder_pub::entities::ImportFrom;
use flowy_sqlite::kv::KVStorePreferences;
use flowy_user::services::action_interceptor::{
  NotificationInterceptor, ReminderActionInterceptor,
};
use flowy_user::services::authenticate_user::AuthenticateUser;
use flowy_user::user_manager::UserManager;
use flowy_user_pub::workspace_collab::adaptor::WorkspaceCollabAdaptor;
use flowy_user_pub::workspace_service::WorkspaceDataImporter;
use lib_infra::async_trait::async_trait;
use std::collections::HashMap;
use std::convert::TryFrom;
use std::sync::{Arc, Weak};
use tracing::info;

pub struct UserDepsResolver();

impl UserDepsResolver {
  pub async fn resolve(
    authenticate_user: Arc<AuthenticateUser>,
    collab_builder: Weak<WorkspaceCollabAdaptor>,
    server_provider: Weak<ServerProvider>,
    store_preference: Arc<KVStorePreferences>,
    database_manager: Weak<DatabaseManager>,
    folder_manager: Weak<FolderManager>,
  ) -> Arc<UserManager> {
    let workspace_service_impl = Arc::new(UserWorkspaceServiceImpl {
      database_manager,
      folder_manager,
    });
    UserManager::new(
      server_provider,
      store_preference,
      collab_builder,
      authenticate_user,
      workspace_service_impl,
    )
  }
}

pub struct UserWorkspaceServiceImpl {
  pub database_manager: Weak<DatabaseManager>,
  pub folder_manager: Weak<FolderManager>,
}

#[async_trait]
impl WorkspaceDataImporter for UserWorkspaceServiceImpl {
  async fn import_views(
    &self,
    source: &ImportFrom,
    views: Vec<ParentChildViews>,
    orphan_views: Vec<ParentChildViews>,
    parent_view_id: Option<String>,
  ) -> FlowyResult<()> {
    match source {
      ImportFrom::AnonUser => {
        self
          .folder_manager
          .upgrade()
          .ok_or_else(FlowyError::ref_drop)?
          .insert_views_as_spaces(views, orphan_views)
          .await?;
      },
      ImportFrom::AppFlowyDataFolder => {
        self
          .folder_manager
          .upgrade()
          .ok_or_else(FlowyError::ref_drop)?
          .insert_views_with_parent(views, orphan_views, parent_view_id)
          .await?;
      },
    }
    Ok(())
  }

  async fn import_database_views(
    &self,
    ids_by_database_id: HashMap<String, Vec<String>>,
  ) -> FlowyResult<()> {
    self
      .database_manager
      .upgrade()
      .ok_or_else(FlowyError::ref_drop)?
      .update_database_indexing(ids_by_database_id)
      .await?;
    Ok(())
  }
}

pub struct NotificationInterceptorImpl;

#[async_trait]
impl NotificationInterceptor for NotificationInterceptorImpl {
  async fn receive_notification(&self, notification: WorkspaceNotification) {
    info!("Received notification: {:?}", notification);
  }
}

pub struct ReminderActionInterceptorImpl {
  pub(crate) document_manager: Weak<DocumentManager>,
}

#[async_trait]
impl ReminderActionInterceptor for ReminderActionInterceptorImpl {
  async fn add_reminder(&self, reminder: Reminder) -> Result<(), Error> {
    if let Some(document_manager) = self.document_manager.upgrade() {
      match DocumentReminder::try_from(reminder) {
        Ok(reminder) => {
          document_manager
            .handle_reminder_action(DocumentReminderAction::Add { reminder })
            .await;
        },
        Err(e) => tracing::error!("Failed to add reminder: {:?}", e),
      }
    }
    Ok(())
  }

  async fn remove_reminder(&self, reminder_id: &str) -> Result<(), Error> {
    let reminder_id = reminder_id.to_string();
    if let Some(document_manager) = self.document_manager.upgrade() {
      let action = DocumentReminderAction::Remove { reminder_id };
      document_manager.handle_reminder_action(action).await;
    }
    Ok(())
  }

  async fn update_reminder(&self, reminder: Reminder) -> Result<(), Error> {
    if let Some(document_manager) = self.document_manager.upgrade() {
      match DocumentReminder::try_from(reminder) {
        Ok(reminder) => {
          document_manager
            .handle_reminder_action(DocumentReminderAction::Update { reminder })
            .await;
        },
        Err(e) => tracing::error!("Failed to update reminder: {:?}", e),
      }
    }
    Ok(())
  }
}
