use crate::entities::ConnectStateNotificationPB;
use crate::notification::{send_notification, UserNotification};
use crate::services::action_interceptor::ActionInterceptors;
use crate::user_manager::UserManager;
use arc_swap::ArcSwapOption;
use chrono::{DateTime, Utc};
use client_api::entity::server_info_dto::{ServerInfo, SignedServerInfoData};
use client_api::v2::{ConnectState, RetryConfig, WorkspaceController, WorkspaceControllerOptions};
use client_api::verify_signature;
use dashmap::Entry;
use flowy_error::{FlowyError, FlowyResult};
use flowy_sqlite::kv::KVStorePreferences;
use flowy_user_pub::cloud::UserServerProvider;
use flowy_user_pub::entities::WorkspaceType;
use std::ops::Deref;
use std::sync::{Arc, Weak};
use tokio_stream::StreamExt;
use tracing::{debug, error, info, instrument, trace, warn};
use uuid::Uuid;

fn sync_server_info_for_user(
  uid: i64,
  server_provider: Weak<dyn UserServerProvider>,
  store_preferences: Weak<KVStorePreferences>,
) {
  tokio::spawn(async move {
    info!("Syncing server info for user: {}", uid);
    let store_preferences = store_preferences
      .upgrade()
      .ok_or_else(|| FlowyError::internal().with_context("Failed to upgrade store preferences"))?;

    let server_provider = server_provider
      .upgrade()
      .ok_or_else(|| FlowyError::internal().with_context("Failed to upgrade cloud service"))?;

    let server_info = server_provider.sync_server_info(uid).await?;
    let key = format!("server_info_{}", uid);

    debug!("server info: {:?}", server_info);
    store_preferences.set_object(&key, &server_info)?;
    Ok::<_, FlowyError>(())
  });
}

impl UserManager {
  fn sync_server_info(&self, uid: i64) {
    sync_server_info_for_user(
      uid,
      self.cloud_service.clone(),
      Arc::downgrade(&self.store_preferences),
    );
  }

  pub async fn get_server_info(&self) -> Option<ServerInfo> {
    let uid = self.user_id().ok()?;
    let key = format!("server_info_{}", uid);
    let info = self.store_preferences.get_object::<ServerInfo>(&key)?;
    let data = SignedServerInfoData::from(&info);
    match verify_signature(&info.sig, &data) {
      Ok(_) => Some(info),
      Err(err) => {
        error!("Failed to verify server info signature: {}", err);
        None
      },
    }
  }

  pub fn update_network_reachable(&self, reachable: bool) {
    if reachable {
      if let Ok(workspace_id) = self.workspace_id() {
        if let Some(c) = self.controller_by_wid.get(&workspace_id).map(|v| v.clone()) {
          info!(
            "Network is reachable, reconnecting workspace: {}",
            workspace_id
          );
          c.controller.reconnect_if_need();
        }
      }
    }
  }

  pub fn reconnect_if_needed(&self) {
    if let Ok(workspace_id) = self.workspace_id() {
      debug!(
        "Reconnecting workspace:{} websocket if needed",
        workspace_id
      );
      if let Some(c) = self.controller_by_wid.get(&workspace_id).map(|v| v.clone()) {
        info!("Reconnecting workspace: {}", workspace_id);
        c.controller.reconnect_if_need();
      } else {
        warn!(
          "No controller found for workspace: {} when reconnect",
          workspace_id
        );
      }
    }
  }

  #[cfg(debug_assertions)]
  pub async fn disconnect_workspace_ws_conn(&self, workspace_id: &Uuid) -> FlowyResult<()> {
    if let Some(c) = self.controller_by_wid.get(workspace_id) {
      c.disconnect().await?;
    }
    Ok(())
  }

  #[cfg(debug_assertions)]
  pub async fn start_ws_connect_manually(&self, workspace_id: &Uuid) -> FlowyResult<()> {
    if let Some(c) = self.controller_by_wid.get(workspace_id) {
      c.connect().await?;
    }
    Ok(())
  }

  pub(crate) fn spawn_periodically_check_workspace_control(&self) {
    let secs = if cfg!(debug_assertions) { 15 } else { 30 };
    let mut interval = tokio::time::interval(tokio::time::Duration::from_secs(secs));
    let weak_controller_by_wid = Arc::downgrade(&self.controller_by_wid);
    tokio::spawn(async move {
      loop {
        interval.tick().await;
        match weak_controller_by_wid.upgrade() {
          None => {
            info!("exit periodically check active/inactive workspace");
            break;
          },
          Some(c) => {
            let ids = c.iter().map(|v| *v.key()).collect::<Vec<_>>();
            for id in ids {
              let removed = c.remove_if(&id, |_, w| w.is_inactive());
              if let Some((id, w)) = removed {
                let _ = w.disconnect().await;
                info!("remove inactive workspace {} collab controller", id);
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
    uid: i64,
    workspace_id: &Uuid,
    workspace_type: &WorkspaceType,
    cloud_service: &Arc<dyn UserServerProvider>,
  ) -> Result<Weak<WorkspaceController>, FlowyError> {
    let sync_enabled = matches!(workspace_type, WorkspaceType::Cloud);
    let entry = self.controller_by_wid.entry(*workspace_id);
    let retry_config = RetryConfig::default();

    debug!(
      "Initializing workspace controller for workspace: {}, type: {:?}, sync_enabled: {}",
      workspace_id, workspace_type, sync_enabled
    );
    self.sync_server_info(uid);

    // build the workspace controller
    let controller = match entry {
      Entry::Occupied(mut value) => {
        value.get_mut().mark_active();
        let controller = value.get().clone();
        spawn_connect(controller.clone(), workspace_type);
        Arc::downgrade(&controller)
      },
      Entry::Vacant(entry) => {
        let uid = self.user_id()?;
        let collab_db = self.authenticate_user.database.get_weak_collab_db(uid)?;
        let device_id = self.authenticate_user.device_id()?;
        let options = WorkspaceControllerOptions {
          url: cloud_service.ws_url(),
          workspace_id: *workspace_id,
          uid,
          device_id,
          sync_eagerly: true,
          sync_enabled,
        };
        let token_provider = cloud_service.get_token_provider()?;
        let workspace_controller = Arc::new(WorkspaceController::new_with_rocksdb(
          options,
          collab_db,
          retry_config,
          token_provider,
        )?);
        let controller = WorkspaceControllerLifeCycle::new(
          *workspace_type,
          workspace_controller.clone(),
          Arc::downgrade(&self.action_interceptors),
        );

        entry.insert(controller.clone());
        let weak_controller = Arc::downgrade(&workspace_controller);
        spawn_subscribe_websocket_connect_state(workspace_controller.clone());
        spawn_connect(controller, workspace_type);
        weak_controller
      },
    };
    Ok(controller)
  }

  pub(crate) async fn get_ws_connect_state(&self) -> FlowyResult<ConnectState> {
    let workspace_id = self.workspace_id()?;
    if self.authenticate_user.is_anon().await? {
      Ok(ConnectState::Connected)
    } else if let Some(controller) = self.controller_by_wid.get(&workspace_id) {
      Ok(controller.connect_state())
    } else {
      warn!("Connection not found for workspace: {}", workspace_id);
      Ok(ConnectState::Disconnected { reason: None })
    }
  }

  #[instrument(skip(self), err)]
  pub(crate) async fn start_ws_connect_state(&self) -> FlowyResult<()> {
    let workspace_id = self.workspace_id()?;
    send_notification(
      workspace_id.to_string(),
      UserNotification::WebSocketConnectState,
    )
    .payload(ConnectStateNotificationPB::from(ConnectState::Connecting))
    .send();

    if let Some(controller) = self.controller_by_wid.get(&workspace_id) {
      info!(
        "Start workspace:{} websocket connect manually",
        workspace_id
      );
      controller.connect().await?;

      send_notification(
        workspace_id.to_string(),
        UserNotification::WebSocketConnectState,
      )
      .payload(ConnectStateNotificationPB::from(ConnectState::Connected))
      .send();
    }
    Ok(())
  }
}
fn spawn_subscribe_websocket_connect_state(controller: Arc<WorkspaceController>) {
  let workspace_id = controller.workspace_id();
  let mut rx = controller.subscribe_connect_state();
  let weak_controller = Arc::downgrade(&controller);
  tokio::spawn(async move {
    while let Some(value) = rx.next().await {
      if weak_controller.upgrade().is_none() {
        info!(
          "Workspace controller for {} is dropped, stopping connect state subscription",
          workspace_id
        );
        break;
      }
      send_notification(
        workspace_id.to_string(),
        UserNotification::WebSocketConnectState,
      )
      .payload(ConnectStateNotificationPB::from(value.clone()))
      .send();
    }
  });
}

fn spawn_connect(controller: WorkspaceControllerLifeCycle, workspace_type: &WorkspaceType) {
  debug!(
    "Spawning websocket connect for workspace:{}/{}",
    controller.workspace_id(),
    workspace_type,
  );

  tokio::spawn(async move {
    match controller.connect().await {
      Ok(_) => {
        debug!(
          "workspace: {}, type: {:?} websocket connected successfully",
          controller.workspace_id(),
          controller.workspace_type
        );
      },
      Err(err) => {
        error!("spawn connect failed: {:?}", err);
      },
    }
  });
}

#[derive(Clone)]
pub(crate) struct WorkspaceControllerLifeCycle {
  workspace_type: WorkspaceType,
  controller: Arc<WorkspaceController>,
  inactive_since: Option<DateTime<Utc>>,
  interceptors: Weak<ArcSwapOption<ActionInterceptors>>,
}

impl Deref for WorkspaceControllerLifeCycle {
  type Target = Arc<WorkspaceController>;

  fn deref(&self) -> &Self::Target {
    &self.controller
  }
}

impl WorkspaceControllerLifeCycle {
  pub(crate) fn new(
    workspace_type: WorkspaceType,
    controller: Arc<WorkspaceController>,
    interceptors: Weak<ArcSwapOption<ActionInterceptors>>,
  ) -> Self {
    let this = Self {
      workspace_type,
      controller,
      inactive_since: None,
      interceptors,
    };
    this.spawn_observe_workspace_notification();
    this
  }

  fn is_inactive(&self) -> bool {
    trace!(
      "Check if workspace {} is inactive, inactive_since: {:?}, inactive seconds: {}",
      self.workspace_id(),
      self.inactive_since,
      self
        .inactive_since
        .as_ref()
        .map(|t| Utc::now().signed_duration_since(*t).num_seconds())
        .unwrap_or(0)
    );
    match &self.inactive_since {
      None => false,
      Some(t) => {
        if cfg!(debug_assertions) {
          Utc::now().signed_duration_since(*t).num_seconds() > 60
        } else {
          Utc::now().signed_duration_since(*t).num_seconds() > 120
        }
      },
    }
  }
  fn mark_active(&mut self) {
    info!("Set workspace {} as active workspace", self.workspace_id());
    self.inactive_since = None;
  }

  fn mark_inactive(&mut self) {
    info!(
      "Set workspace {} as inactive workspace",
      self.workspace_id()
    );
    self.inactive_since = Some(Utc::now());
  }

  pub fn spawn_observe_workspace_notification(&self) {
    let weak_interceptors = self.interceptors.clone();
    let mut rx = self.controller.subscribe_notification();
    tokio::spawn(async move {
      while let Ok(notification) = rx.recv().await {
        match weak_interceptors.upgrade() {
          None => {
            info!("Exit observe workspace notification");
            break;
          },
          Some(v) => {
            if let Some(v) = v.load_full() {
              v.notification_handler
                .handle_notification(notification)
                .await;
            } else {
              debug!("Action interceptors is None, cannot handle notification");
            }
          },
        }
      }
    });
  }
}
