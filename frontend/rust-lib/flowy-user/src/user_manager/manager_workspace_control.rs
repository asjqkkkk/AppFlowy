use crate::user_manager::UserManager;
use chrono::{DateTime, Utc};
use client_api::v2::{WorkspaceController, WorkspaceControllerOptions};
use dashmap::Entry;
use flowy_error::FlowyError;
use flowy_user_pub::cloud::UserCloudServiceProvider;
use std::ops::Deref;
use std::sync::{Arc, Weak};
use tracing::{error, info};
use uuid::Uuid;

impl UserManager {
  pub(crate) fn spawn_periodically_check_workspace_control(&self) {
    let mut interval = tokio::time::interval(tokio::time::Duration::from_secs(120));
    let weak_controller_by_wid = Arc::downgrade(&self.controller_by_wid);
    tokio::spawn(async move {
      loop {
        interval.tick().await;
        match weak_controller_by_wid.upgrade() {
          None => {
            break;
          },
          Some(c) => {
            let ids = c.iter().map(|v| *v.key()).collect::<Vec<_>>();
            for id in ids {
              let removed = c.remove_if(&id, |_, w| w.is_inactive());
              if let Some((id, w)) = removed {
                let _ = w.disconnect().await;
                info!("Drop workspace {} collab controller", id);
              }
            }
          },
        }
      }
    });
  }

  pub(crate) fn inactive_controller(&self, workspace_id: &Uuid) {
    if let Some(mut c) = self.controller_by_wid.get_mut(workspace_id) {
      c.mark_inactive();
    };
  }

  pub(crate) fn init_workspace_controller_if_need(
    &self,
    workspace_id: &Uuid,
    cloud_service: &Arc<dyn UserCloudServiceProvider>,
  ) -> Result<Weak<WorkspaceController>, FlowyError> {
    let token = cloud_service.get_token();
    let entry = self.controller_by_wid.entry(*workspace_id);
    let controller = match entry {
      Entry::Occupied(mut value) => {
        value.get_mut().mark_active();
        let controller = value.get().clone();
        spawn_connect(controller.deref().clone(), token);
        Arc::downgrade(&controller)
      },
      Entry::Vacant(entry) => {
        let uid = self.user_id()?;
        let collab_db = self.authenticate_user.database.get_collab_db(uid)?;
        let device_id = self.authenticate_user.device_id()?;
        let options = WorkspaceControllerOptions {
          url: cloud_service.ws_url(),
          workspace_id: *workspace_id,
          uid,
          device_id,
          sync_eagerly: true,
        };
        let workspace_controller =
          Arc::new(WorkspaceController::new_with_rocksdb(options, collab_db)?);
        entry.insert(WorkspaceControllerLifeCycle::new(
          workspace_controller.clone(),
        ));
        let weak_controller = Arc::downgrade(&workspace_controller);
        spawn_connect(workspace_controller, token);
        weak_controller
      },
    };
    Ok(controller)
  }
}

fn spawn_connect(controller: Arc<WorkspaceController>, token: Option<String>) {
  if controller.is_connected() {
    return;
  }

  if let Some(token) = token {
    tokio::spawn(async move {
      if let Err(err) = controller.connect(token).await {
        error!("spawn connect failed: {:?}", err);
      }
    });
  }
}

#[derive(Clone)]
pub(crate) struct WorkspaceControllerLifeCycle {
  controller: Arc<WorkspaceController>,
  inactive_since: Option<DateTime<Utc>>,
}

impl Deref for WorkspaceControllerLifeCycle {
  type Target = Arc<WorkspaceController>;

  fn deref(&self) -> &Self::Target {
    &self.controller
  }
}

impl WorkspaceControllerLifeCycle {
  fn is_inactive(&self) -> bool {
    match &self.inactive_since {
      None => false,
      Some(t) => t.signed_duration_since(Utc::now()).num_minutes() > 10,
    }
  }
  fn mark_active(&mut self) {
    self.inactive_since = None;
  }

  fn mark_inactive(&mut self) {
    self.inactive_since = Some(Utc::now());
  }
  pub(crate) fn new(controller: Arc<WorkspaceController>) -> Self {
    Self {
      controller,
      inactive_since: None,
    }
  }
}
