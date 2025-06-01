use anyhow::Error;
use client_api::entity::WorkspaceNotification;
use collab_entity::reminder::Reminder;
use lib_infra::async_trait::async_trait;

#[async_trait]
pub trait ReminderActionInterceptor: Send + Sync + 'static {
  async fn add_reminder(&self, _reminder: Reminder) -> Result<(), Error> {
    Ok(())
  }
  async fn remove_reminder(&self, _reminder_id: &str) -> Result<(), Error> {
    Ok(())
  }
  async fn update_reminder(&self, _reminder: Reminder) -> Result<(), Error> {
    Ok(())
  }
}

#[async_trait]
pub trait NotificationInterceptor: Send + Sync + 'static {
  async fn receive_notification(&self, notification: WorkspaceNotification);
}

pub struct ActionInterceptors {
  pub reminder: Box<dyn ReminderActionInterceptor>,
  pub notification: Box<dyn NotificationInterceptor>,
}
