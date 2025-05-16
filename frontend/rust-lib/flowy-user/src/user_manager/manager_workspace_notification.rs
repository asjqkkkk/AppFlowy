use crate::user_manager::UserManager;
use client_api::v2::WorkspaceController;
use std::sync::{Arc, Weak};
use tracing::trace;

impl UserManager {
  pub(crate) fn spawn_observe_workspace_notification(&self, controller: Weak<WorkspaceController>) {
    if let Some(controller) = controller.upgrade() {
      let weak_action_interceptors = Arc::downgrade(&self.action_interceptors);
      let mut rx = controller.subscribe_notification();
      tokio::spawn(async move {
        while let Ok(notification) = rx.recv().await {
          match weak_action_interceptors.upgrade() {
            None => {
              trace!("Exit observe workspace notification");
              break;
            },
            Some(v) => {
              if let Some(interceptor) = v.load_full().map(|v| &v.notification) {
                interceptor.receive_notification(notification).await;
              }
            },
          }
        }
      });
    }
  }
}
