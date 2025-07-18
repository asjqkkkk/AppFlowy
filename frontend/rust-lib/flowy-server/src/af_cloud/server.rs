use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Weak};

use crate::af_cloud::define::LoggedUser;
use anyhow::Error;
use client_api::notify::TokenState;
use client_api::{Client, ClientConfiguration};
use flowy_ai_pub::cloud::ChatCloudService;
use flowy_database_pub::cloud::{DatabaseAIService, DatabaseCloudService};
use flowy_document_pub::cloud::DocumentCloudService;
use flowy_error::{ErrorCode, FlowyError};
use flowy_folder_pub::cloud::FolderCloudService;
use flowy_search_pub::cloud::SearchCloudService;
use flowy_server_pub::af_cloud_config::AFCloudConfiguration;
use flowy_storage_pub::cloud::StorageCloudService;
use flowy_user_pub::cloud::{
  UserAuthService, UserBillingService, UserCollabService, UserProfileService, UserWorkspaceService,
};
use flowy_user_pub::entities::UserTokenState;

use super::impls::AFCloudSearchCloudServiceImpl;
use crate::AppFlowyServer;
use crate::af_cloud::impls::{
  AFCloudDatabaseCloudServiceImpl, AFCloudDocumentCloudServiceImpl, AFCloudFileStorageServiceImpl,
  AFCloudFolderCloudServiceImpl, AFCloudUserServiceImpl, CloudChatServiceImpl,
};
use flowy_ai::offline::offline_message_sync::AutoSyncChatService;
use flowy_ai_pub::user_service::AIUserService;
use flowy_search_pub::tantivy_state::DocumentTantivyState;
use lib_infra::async_trait::async_trait;
use semver::Version;
use tokio::sync::{RwLock, watch};
use tokio_stream::wrappers::WatchStream;
use tracing::{debug, error, info, warn};
use url::Url;
use uuid::Uuid;

pub(crate) type AFCloudClient = Client;

pub struct AppFlowyCloudServer {
  pub(crate) config: AFCloudConfiguration,
  pub(crate) client: Arc<AFCloudClient>,
  enable_sync: Arc<AtomicBool>,
  network_reachable: Arc<AtomicBool>,
  logged_user: Arc<dyn LoggedUser>,
  ai_service: Arc<dyn AIUserService>,
  tanvity_state: RwLock<Option<Weak<RwLock<DocumentTantivyState>>>>,
}

impl AppFlowyCloudServer {
  pub fn new(
    config: AFCloudConfiguration,
    enable_sync: bool,
    mut device_id: String,
    client_version: Version,
    logged_user: Arc<dyn LoggedUser>,
    ai_service: Arc<dyn AIUserService>,
  ) -> Self {
    // The device id can't be empty, so we generate a new one if it is.
    if device_id.is_empty() {
      warn!("Device ID is empty, generating a new one");
      device_id = Uuid::new_v4().to_string();
    }
    let api_client = AFCloudClient::new(
      &config.base_url,
      &config.ws_base_url,
      &config.gotrue_url,
      &device_id,
      ClientConfiguration::default()
        .with_compression_buffer_size(10240)
        .with_compression_quality(8),
      &client_version.to_string(),
    );
    let enable_sync = Arc::new(AtomicBool::new(enable_sync));
    let network_reachable = Arc::new(AtomicBool::new(true));
    let api_client = Arc::new(api_client);

    Self {
      config,
      client: api_client,
      enable_sync,
      network_reachable,
      logged_user,
      tanvity_state: Default::default(),
      ai_service,
    }
  }

  fn get_server_impl(&self) -> AFServerImpl {
    let client = if self.enable_sync.load(Ordering::SeqCst) {
      Some(self.client.clone())
    } else {
      None
    };
    AFServerImpl { client }
  }
}

#[async_trait]
impl AppFlowyServer for AppFlowyCloudServer {
  fn set_token(&self, token: &str) -> Result<(), Error> {
    self
      .client
      .restore_token(token)
      .map_err(|err| Error::new(FlowyError::unauthorized().with_context(err)))
  }

  fn get_access_token(&self) -> Option<String> {
    self.client.get_access_token().ok()
  }

  fn set_ai_model(&self, ai_model: &str) -> Result<(), Error> {
    self.client.set_ai_model(ai_model.to_string());
    Ok(())
  }

  fn subscribe_token_state(&self) -> Option<WatchStream<UserTokenState>> {
    let mut token_state_rx = self.client.subscribe_token_state();
    let (watch_tx, watch_rx) = watch::channel(UserTokenState::Init);
    let weak_client = Arc::downgrade(&self.client);
    tokio::spawn(async move {
      while let Ok(token_state) = token_state_rx.recv().await {
        if let Some(client) = weak_client.upgrade() {
          match token_state {
            TokenState::Refresh => match client.get_token() {
              Ok(resp) => {
                let token = serde_json::to_string(&resp).unwrap();
                if let Err(err) = watch_tx.send(UserTokenState::Refresh {
                  token,
                  access_token: resp.access_token,
                }) {
                  error!("Failed to send token after token state changed: {}", err);
                }
              },
              Err(err) => {
                error!("Failed to get token after token state changed: {}", err);
              },
            },
            TokenState::Invalid => {
              let _ = watch_tx.send(UserTokenState::Invalid);
            },
          }
        }
      }
    });

    Some(WatchStream::new(watch_rx))
  }

  fn set_enable_sync(&self, uid: i64, enable: bool) {
    info!("{} cloud sync: {}", uid, enable);
    self.enable_sync.store(enable, Ordering::SeqCst);
  }

  fn set_network_reachable(&self, reachable: bool) {
    self.network_reachable.store(reachable, Ordering::SeqCst);
  }

  fn user_service(&self) -> Arc<dyn UserWorkspaceService> {
    Arc::new(AFCloudUserServiceImpl::new(
      self.get_server_impl(),
      Arc::downgrade(&self.logged_user),
    ))
  }

  fn folder_service(&self) -> Arc<dyn FolderCloudService> {
    Arc::new(AFCloudFolderCloudServiceImpl {
      inner: self.get_server_impl(),
      logged_user: Arc::downgrade(&self.logged_user),
    })
  }

  fn database_service(&self) -> Arc<dyn DatabaseCloudService> {
    Arc::new(AFCloudDatabaseCloudServiceImpl {
      inner: self.get_server_impl(),
      logged_user: Arc::downgrade(&self.logged_user),
    })
  }

  fn database_ai_service(&self) -> Option<Arc<dyn DatabaseAIService>> {
    Some(Arc::new(AFCloudDatabaseCloudServiceImpl {
      inner: self.get_server_impl(),
      logged_user: Arc::downgrade(&self.logged_user),
    }))
  }

  fn document_service(&self) -> Arc<dyn DocumentCloudService> {
    Arc::new(AFCloudDocumentCloudServiceImpl {
      inner: self.get_server_impl(),
      logged_user: Arc::downgrade(&self.logged_user),
    })
  }

  fn chat_service(&self) -> Arc<dyn ChatCloudService> {
    Arc::new(AutoSyncChatService::new(
      Arc::new(CloudChatServiceImpl {
        inner: self.get_server_impl(),
      }),
      self.ai_service.clone(),
    ))
  }

  fn file_storage(&self) -> Option<Arc<dyn StorageCloudService>> {
    Some(Arc::new(AFCloudFileStorageServiceImpl::new(
      self.get_server_impl(),
      self.config.maximum_upload_file_size_in_bytes,
    )))
  }

  async fn search_service(&self) -> Option<Arc<dyn SearchCloudService>> {
    let state = self.tanvity_state.read().await.clone();
    Some(Arc::new(AFCloudSearchCloudServiceImpl {
      server: self.get_server_impl(),
      state,
    }))
  }

  async fn set_tanvity_state(&self, state: Option<Weak<RwLock<DocumentTantivyState>>>) {
    *self.tanvity_state.write().await = state;
  }

  async fn refresh_access_token(&self, reason: &str) {
    let _ = self.client.refresh_token(reason).await;
  }

  fn billing_service(&self) -> Option<Arc<dyn UserBillingService>> {
    Some(Arc::new(AFCloudUserServiceImpl::new(
      self.get_server_impl(),
      Arc::downgrade(&self.logged_user),
    )))
  }

  fn collab_service(&self) -> Arc<dyn UserCollabService> {
    Arc::new(AFCloudUserServiceImpl::new(
      self.get_server_impl(),
      Arc::downgrade(&self.logged_user),
    ))
  }

  fn auth_service(&self) -> Arc<dyn UserAuthService> {
    Arc::new(AFCloudUserServiceImpl::new(
      self.get_server_impl(),
      Arc::downgrade(&self.logged_user),
    ))
  }

  fn user_profile_service(&self) -> Arc<dyn UserProfileService> {
    Arc::new(AFCloudUserServiceImpl::new(
      self.get_server_impl(),
      Arc::downgrade(&self.logged_user),
    ))
  }
}

pub trait AFServer: Send + Sync + 'static {
  fn get_client(&self) -> Option<Arc<AFCloudClient>>;
  fn try_get_client(&self) -> Result<Arc<AFCloudClient>, Error>;

  fn is_appflowy_hosted(&self) -> bool;
}

#[derive(Clone)]
pub struct AFServerImpl {
  client: Option<Arc<AFCloudClient>>,
}

impl AFServer for AFServerImpl {
  fn get_client(&self) -> Option<Arc<AFCloudClient>> {
    self.client.clone()
  }

  fn try_get_client(&self) -> Result<Arc<AFCloudClient>, Error> {
    match self.client.clone() {
      None => Err(
        FlowyError::new(
          ErrorCode::DataSyncRequired,
          "Data Sync is disabled, please enable it first",
        )
        .into(),
      ),
      Some(client) => Ok(client),
    }
  }

  fn is_appflowy_hosted(&self) -> bool {
    match self.client.as_ref() {
      None => false,
      Some(client) => {
        let mut appflowy_hosted_urs =
          vec!["appflowy.com", "beta.appflowy.cloud", "test.appflowy.cloud"];

        if cfg!(debug_assertions) {
          appflowy_hosted_urs.push("localhost");
          appflowy_hosted_urs.push("127.0.0.1");
        }

        match Url::parse(&client.base_url) {
          Ok(url) => {
            if let Some(host) = url.host_str() {
              let result = appflowy_hosted_urs.contains(&host);
              debug!("is_appflowy_hosted: {}, base_url: {}", result, host);
              result
            } else {
              error!("Could not get host from URL: {}", &client.base_url);
              false
            }
          },
          Err(e) => {
            error!("Invalid base URL: {}, {:?}", &client.base_url, e);
            false
          },
        }
      },
    }
  }
}
