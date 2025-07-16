use crate::app_life_cycle::LoggedWorkspaceImpl;
use crate::deps_resolve::{AIUserServiceImpl, MultiSourceVSTanvityImpl};
use crate::editing_collab_data_provider::EditingCollabDataProvider;
use crate::{AppFlowyCoreConfig, LoggedUserImpl};
use arc_swap::{ArcSwap, ArcSwapOption};
use client_api::v2::ConnectState;
use collab::entity::EncodedCollab;
use collab_entity::CollabType;
use dashmap::try_result::TryResult;
use dashmap::DashMap;
use flowy_ai::local_ai::controller::LocalAIController;
use flowy_ai_pub::cloud::ChatCloudService;
use flowy_ai_pub::entities::UnindexedCollab;
use flowy_database_pub::cloud::DatabaseCloudService;
use flowy_document_pub::cloud::DocumentCloudService;
use flowy_error::{FlowyError, FlowyResult};
use flowy_folder_pub::cloud::FolderCloudService;
use flowy_search_pub::cloud::SearchCloudService;
use flowy_search_pub::tantivy_state::DocumentTantivyState;
use flowy_server::af_cloud::define::LoggedWorkspace;
use flowy_server::af_cloud::AppFlowyCloudServer;
use flowy_server::local_server::LocalServer;
use flowy_server::{AppFlowyEncryption, AppFlowyServer, EmbeddingWriter, EncryptionImpl};
use flowy_server_pub::AuthenticatorType;
use flowy_sqlite::kv::KVStorePreferences;
use flowy_user::services::authenticate_user::AuthenticateUser;
use flowy_user_pub::entities::*;
use futures::stream::BoxStream;
use lib_infra::async_trait::async_trait;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Weak};
use tokio::sync::RwLock;
use tracing::{error, instrument};
use uuid::Uuid;

pub struct ServerProvider {
  config: AppFlowyCoreConfig,
  pub(crate) providers: DashMap<AuthProvider, Arc<dyn AppFlowyServer>>,
  pub(crate) auth_provider: ArcSwap<AuthProvider>,
  authenticate_user: Weak<AuthenticateUser>,
  logged_workspace: ArcSwapOption<LoggedWorkspaceImpl>,
  pub local_ai: Arc<LocalAIController>,
  pub uid: Arc<ArcSwapOption<i64>>,
  pub user_enable_sync: Arc<AtomicBool>,
  pub encryption: Arc<dyn AppFlowyEncryption>,
  pub indexed_data_writer: Option<Weak<EditingCollabDataProvider>>,
}

// Our little guard wrapper:

/// Determine current server type from ENV
pub fn current_server_type() -> AuthProvider {
  match AuthenticatorType::from_env() {
    AuthenticatorType::Local => AuthProvider::Local,
    AuthenticatorType::AppFlowyCloud => AuthProvider::Cloud,
  }
}

impl ServerProvider {
  pub fn new(
    config: AppFlowyCoreConfig,
    store_preferences: Weak<KVStorePreferences>,
    authenticate_user: Weak<AuthenticateUser>,
    indexed_data_writer: Option<Weak<EditingCollabDataProvider>>,
  ) -> Self {
    let initial_auth = current_server_type();
    let auth_provider = ArcSwap::from(Arc::new(initial_auth));
    let encryption = Arc::new(EncryptionImpl::new(None)) as Arc<dyn AppFlowyEncryption>;
    let ai_user = Arc::new(AIUserServiceImpl(authenticate_user.clone()));
    let local_ai = Arc::new(LocalAIController::new(store_preferences, ai_user.clone()));

    ServerProvider {
      config,
      providers: DashMap::new(),
      encryption,
      user_enable_sync: Arc::new(AtomicBool::new(true)),
      auth_provider,
      authenticate_user,
      logged_workspace: Default::default(),
      uid: Default::default(),
      local_ai,
      indexed_data_writer,
    }
  }

  pub fn get_workspace_type(&self, workspace_id: &Uuid) -> Result<WorkspaceType, FlowyError> {
    let auth_user = self
      .authenticate_user
      .upgrade()
      .ok_or_else(FlowyError::ref_drop)?;
    auth_user.get_workspace_type(workspace_id)
  }

  #[instrument(level = "debug", skip(self), err)]
  pub fn get_current_workspace_type(&self) -> Result<WorkspaceType, FlowyError> {
    let auth_user = self
      .authenticate_user
      .upgrade()
      .ok_or_else(FlowyError::ref_drop)?;
    auth_user.get_current_workspace_type()
  }

  pub fn get_chat_service(&self) -> FlowyResult<Arc<dyn ChatCloudService>> {
    let workspace_type = self.get_current_workspace_type()?;
    let server = self.get_server_from_workspace_type(workspace_type);
    Ok(server?.chat_service())
  }

  pub fn get_folder_service(&self) -> FlowyResult<Arc<dyn FolderCloudService>> {
    let workspace_type = self.get_current_workspace_type()?;
    let server = self.get_server_from_workspace_type(workspace_type);
    Ok(server?.folder_service())
  }

  pub fn get_database_service(&self) -> FlowyResult<Arc<dyn DatabaseCloudService>> {
    let workspace_type = self.get_current_workspace_type()?;
    let server = self.get_server_from_workspace_type(workspace_type);
    Ok(server?.database_service())
  }

  pub fn get_document_service(&self) -> FlowyResult<Arc<dyn DocumentCloudService>> {
    let workspace_type = self.get_current_workspace_type()?;
    let server = self.get_server_from_workspace_type(workspace_type);
    Ok(server?.document_service())
  }

  pub async fn get_search_service(&self) -> FlowyResult<Option<Arc<dyn SearchCloudService>>> {
    let workspace_type = self.get_current_workspace_type()?;
    let server = self.get_server_from_workspace_type(workspace_type);
    Ok(server?.search_service().await)
  }

  async fn set_tanvity_state(&self, tanvity_state: Option<Weak<RwLock<DocumentTantivyState>>>) {
    let tanvity_store = Arc::new(MultiSourceVSTanvityImpl::new(tanvity_state.clone()));

    self
      .local_ai
      .set_retriever_sources(vec![tanvity_store])
      .await;

    match self.providers.try_get(self.auth_provider.load().as_ref()) {
      TryResult::Present(r) => {
        r.set_tanvity_state(tanvity_state).await;
      },
      TryResult::Absent => {},
      TryResult::Locked => {
        error!("ServerProvider: Failed to get server for auth type");
      },
    }
  }

  pub async fn on_launch_if_authenticated(
    &self,
    tanvity_state: Option<Weak<RwLock<DocumentTantivyState>>>,
  ) {
    self.set_tanvity_state(tanvity_state).await;
  }

  pub fn set_logged_workspace(&self, logged_workspace: LoggedWorkspaceImpl) {
    self
      .logged_workspace
      .store(Some(Arc::new(logged_workspace)));
  }

  pub async fn on_sign_in(&self, tanvity_state: Option<Weak<RwLock<DocumentTantivyState>>>) {
    self.set_tanvity_state(tanvity_state).await;
  }

  pub async fn on_workspace_opened(
    &self,
    tanvity_state: Option<Weak<RwLock<DocumentTantivyState>>>,
  ) {
    self.set_tanvity_state(tanvity_state).await;
  }

  pub fn subscribe_ws_state(&self) -> Option<BoxStream<'static, ConnectState>> {
    let workspace = self.logged_workspace.load_full()?;
    workspace.subscribe_ws_state().ok()
  }

  pub fn get_ws_state(&self) -> FlowyResult<ConnectState> {
    self
      .logged_workspace
      .load_full()
      .ok_or_else(|| FlowyError::internal().with_context("logged workspace not initialized"))?
      .ws_state()
  }

  pub fn get_current_auth_provider(&self) -> AuthProvider {
    *self.auth_provider.load_full().as_ref()
  }

  pub fn get_server_from_workspace_type(
    &self,
    workspace_type: WorkspaceType,
  ) -> FlowyResult<Arc<dyn AppFlowyServer>> {
    let auth_provider = AuthProvider::from(workspace_type);
    self.get_server_from_auth_provider(auth_provider)
  }

  pub fn get_server(&self) -> FlowyResult<Arc<dyn AppFlowyServer>> {
    let auth_provider = self.get_current_auth_provider();
    self.get_server_from_auth_provider(auth_provider)
  }

  pub fn get_server_from_auth_provider(
    &self,
    auth_type: AuthProvider,
  ) -> FlowyResult<Arc<dyn AppFlowyServer>> {
    if let Some(r) = self.providers.get(&auth_type) {
      return Ok(r.value().clone());
    }

    let server: Arc<dyn AppFlowyServer> = match auth_type {
      AuthProvider::Local => {
        let embedding_writer = self.indexed_data_writer.clone().map(|w| {
          Arc::new(EmbeddingWriterImpl {
            indexed_data_writer: w,
          }) as Arc<dyn EmbeddingWriter>
        });
        Arc::new(LocalServer::new(
          Arc::new(LoggedUserImpl(self.authenticate_user.clone())),
          self.local_ai.clone(),
          embedding_writer,
        ))
      },
      AuthProvider::Cloud => {
        let cfg = self
          .config
          .cloud_config
          .clone()
          .ok_or_else(|| FlowyError::internal().with_context("Missing cloud config"))?;
        Arc::new(AppFlowyCloudServer::new(
          cfg,
          self.user_enable_sync.load(Ordering::Acquire),
          self.config.device_id.clone(),
          self.config.app_version.clone(),
          Arc::new(LoggedUserImpl(self.authenticate_user.clone())),
          Arc::new(AIUserServiceImpl(self.authenticate_user.clone())),
        ))
      },
    };

    self.providers.insert(auth_type, server);
    let guard = self.providers.get(&auth_type).unwrap();
    Ok(guard.clone())
  }
}

struct EmbeddingWriterImpl {
  indexed_data_writer: Weak<EditingCollabDataProvider>,
}

#[async_trait]
impl EmbeddingWriter for EmbeddingWriterImpl {
  async fn index_encoded_collab(
    &self,
    workspace_id: Uuid,
    object_id: Uuid,
    data: EncodedCollab,
    collab_type: CollabType,
  ) -> FlowyResult<()> {
    let indexed_data_writer = self.indexed_data_writer.upgrade().ok_or_else(|| {
      FlowyError::internal().with_context("Failed to upgrade InstantIndexedDataWriter")
    })?;
    indexed_data_writer
      .index_encoded_collab(workspace_id, object_id, data, collab_type)
      .await?;
    Ok(())
  }

  async fn index_unindexed_collab(&self, data: UnindexedCollab) -> FlowyResult<()> {
    let indexed_data_writer = self.indexed_data_writer.upgrade().ok_or_else(|| {
      FlowyError::internal().with_context("Failed to upgrade InstantIndexedDataWriter")
    })?;
    indexed_data_writer.index_unindexed_collab(data).await?;
    Ok(())
  }
}
