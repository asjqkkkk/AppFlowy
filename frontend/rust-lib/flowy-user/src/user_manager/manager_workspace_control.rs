use crate::entities::ConnectStateNotificationPB;
use crate::notification::{send_notification, UserNotification};
use crate::services::action_interceptor::ActionInterceptors;
use crate::user_manager::UserManager;
use arc_swap::ArcSwapOption;
use chrono::{DateTime, Utc};
use client_api::entity::auth_dto::{MetadataKey, UpdateUserParams};
use client_api::entity::server_info_dto::{ServerInfo, SignedServerInfoData};
use client_api::entity::user_dto::UserTimezone;
use client_api::v2::{ConnectState, RetryConfig, WorkspaceController, WorkspaceControllerOptions};
use client_api::verify_signature;
use dashmap::Entry;
use flowy_error::{FlowyError, FlowyResult};
use flowy_sqlite::kv::KVStorePreferences;
use flowy_user_pub::cloud::UserServerProvider;
use flowy_user_pub::entities::WorkspaceType;
use flowy_user_pub::server_info::ServerInfoProvider;
use lib_infra::async_trait::async_trait;
use std::ops::Deref;
use std::sync::{Arc, Weak};
use tokio_stream::StreamExt;
use tokio_util::sync::CancellationToken;
use tracing::{debug, error, info, instrument, trace, warn};
use uuid::Uuid;

fn sync_server_info_for_user(
  server_provider: Weak<dyn UserServerProvider>,
  store_preferences: Weak<KVStorePreferences>,
  ret: Option<tokio::sync::oneshot::Sender<Result<ServerInfo, FlowyError>>>,
) {
  tokio::spawn(async move {
    let store_preferences = store_preferences
      .upgrade()
      .ok_or_else(|| FlowyError::internal().with_context("Failed to upgrade store preferences"))?;

    let server_provider = server_provider
      .upgrade()
      .ok_or_else(|| FlowyError::internal().with_context("Failed to upgrade cloud service"))?;

    match server_provider.sync_server_info().await {
      Ok(server_info) => {
        let key = server_info_key()?;
        debug!("server info: {:?}", server_info);
        store_preferences.set_object(&key, &server_info)?;

        if let Some(ret) = ret {
          let _ = ret.send(Ok(server_info));
        }
      },
      Err(err) => {
        if let Some(ret) = ret {
          let _ = ret.send(Err(err));
        }
      },
    }
    Ok::<_, FlowyError>(())
  });
}

/// URL-aware server info sync that stops when the server URL changes or cancellation token is triggered
pub(crate) async fn sync_server_info_with_url(
  server_url: String,
  server_provider: Weak<dyn UserServerProvider>,
  store_preferences: Weak<KVStorePreferences>,
  cancel_token: CancellationToken,
) {
  let mut interval = tokio::time::interval(tokio::time::Duration::from_secs(300)); // 5 minutes
  info!("Started server sync for URL: {}", server_url);

  loop {
    tokio::select! {
      _ = cancel_token.cancelled() => {
        break;
      }
      _ = interval.tick() => {
        // Check if server URL has changed before syncing
        let current_url = match get_current_server_url() {
          Ok(url) => url,
          Err(_) => {
            info!("Cannot get current server URL, stopping sync for: {}", server_url);
            break;
          }
        };

        if current_url != server_url {
          info!("Server URL changed from {} to {}, stopping sync", server_url, current_url);
          break;
        }

        // Perform sync with URL validation
        debug!("Syncing server info for URL: {}", server_url);
        if let Err(err) = sync_server_info_once( &server_provider, &store_preferences).await {
          error!("Failed to sync server info for URL {}: {}", server_url, err);
          // Continue the loop to retry on next interval
        }
      }
    }
  }

  info!("Server sync stopped for URL: {}", server_url);
}

/// Performs a single server info sync operation
async fn sync_server_info_once(
  server_provider: &Weak<dyn UserServerProvider>,
  store_preferences: &Weak<KVStorePreferences>,
) -> Result<(), FlowyError> {
  let store_preferences = store_preferences
    .upgrade()
    .ok_or_else(|| FlowyError::internal().with_context("Failed to upgrade store preferences"))?;

  let server_provider = server_provider
    .upgrade()
    .ok_or_else(|| FlowyError::internal().with_context("Failed to upgrade cloud service"))?;

  let server_info = server_provider.sync_server_info().await?;
  let key = server_info_key()?;

  debug!("server info: {:?}", server_info);
  store_preferences.set_object(&key, &server_info)?;
  Ok(())
}

/// Gets the current server URL from environment variables
pub fn get_current_server_url() -> Result<String, FlowyError> {
  use flowy_server_pub::af_cloud_config::APPFLOWY_CLOUD_BASE_URL;

  std::env::var(APPFLOWY_CLOUD_BASE_URL).map_err(|_| {
    FlowyError::internal().with_context("APPFLOWY_CLOUD_BASE_URL not found in environment")
  })
}
pub fn server_info_key() -> FlowyResult<String> {
  let url = get_current_server_url()?;
  Ok(format!("server_info_{}", url))
}

impl UserManager {
  pub fn sync_server_info(
    &self,
    ret: Option<tokio::sync::oneshot::Sender<Result<ServerInfo, FlowyError>>>,
  ) {
    sync_server_info_for_user(
      self.cloud_service.clone(),
      Arc::downgrade(&self.store_preferences),
      ret,
    );
  }

  fn sync_client_default_timezone(&self, uid: i64) {
    match iana_time_zone::get_timezone() {
      Ok(default_timezone) => {
        let timezone_key = format!("{}_client_timezone", uid);
        if let Some(tz) = self
          .store_preferences
          .get_object::<UserTimezone>(&timezone_key)
        {
          // User already has a timezone set
          if tz.timezone.is_some() {
            return;
          }

          if tz.default_timezone == default_timezone {
            debug!("Client timezone is already set to: {}", default_timezone);
            return;
          }
        }

        let weak_store_preferences = Arc::downgrade(&self.store_preferences);
        let weak_cloud_service = self.cloud_service.clone();

        tokio::spawn(async move {
          let tz = UserTimezone {
            default_timezone: default_timezone.clone(),
            timezone: None,
          };
          let params = UpdateUserParams::new().with_metadata_key(MetadataKey::Timezone, tz.clone());
          const MAX_RETRIES: u32 = 3;
          const RETRY_DELAY_SECS: u64 = 10;
          for attempt in 1..=MAX_RETRIES {
            let Some(store_preferences) = weak_store_preferences.upgrade() else {
              debug!("Store preferences dropped, cancelling timezone sync");
              return;
            };

            let Some(cloud_service) = weak_cloud_service.upgrade() else {
              debug!("Cloud service dropped, cancelling timezone sync");
              return;
            };

            let Ok(user_service) = cloud_service.user_profile_service() else {
              debug!("User service unavailable, cancelling timezone sync");
              return;
            };

            match user_service.update_user(uid, params.clone()).await {
              Ok(_) => {
                debug!("Successfully updated timezone to: {:?}", tz);
                let _ = store_preferences.set_object(&timezone_key, &tz);
                return;
              },
              Err(err) => {
                if attempt < MAX_RETRIES {
                  error!(
                    "Failed to update user timezone (attempt {}/{}): {:?}, retrying in {} seconds",
                    attempt, MAX_RETRIES, err, RETRY_DELAY_SECS
                  );
                  tokio::time::sleep(tokio::time::Duration::from_secs(RETRY_DELAY_SECS)).await;
                } else {
                  error!(
                    "Failed to update user timezone after {} attempts: {:?}",
                    MAX_RETRIES, err
                  );
                }
              },
            }
          }
        });
      },
      Err(err) => {
        error!("Failed to get client timezone: {:?}", err);
      },
    }
  }

  pub async fn get_server_info(&self) -> Option<ServerInfo> {
    let key = server_info_key().ok()?;
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

    // Start URL-bound server info sync
    if let Ok(current_url) = get_current_server_url() {
      self.start_server_sync_for_url(current_url);
    } else {
      // Fallback to old sync method if URL detection fails
      self.sync_server_info(None);
    }

    self.sync_client_default_timezone(uid);

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

#[async_trait]
impl ServerInfoProvider for UserManager {
  async fn get_server_info(&self) -> Option<ServerInfo> {
    self.get_server_info().await
  }
}
