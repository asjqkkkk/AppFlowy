use crate::server_layer::ServerProvider;
use client_api::entity::ai_dto::RepeatedRelatedQuestion;
use client_api::entity::workspace_dto::PublishInfoView;
use client_api::entity::PublishInfo;
use collab::entity::EncodedCollab;
use collab_entity::CollabType;
use flowy_ai_pub::cloud::search_dto::{
  SearchDocumentResponseItem, SearchResult, SearchSummaryResult,
};
use flowy_ai_pub::cloud::{
  AIModel, ChatCloudService, ChatMessage, ChatMessageType, ChatSettings, CompleteTextParams,
  CreateCollabParams, CreatedChatMessage, MessageCursor, ModelList, QueryCollab,
  RepeatedChatMessage, ResponseFormat, StreamAnswer, StreamComplete, UpdateChatParams,
};
use flowy_database_pub::cloud::{
  DatabaseAIService, DatabaseCloudService, DatabaseSnapshot, EncodeCollabByOid, SummaryRowContent,
  TranslateRowContent, TranslateRowResponse,
};
use flowy_document::deps::DocumentData;
use flowy_document_pub::cloud::{DocumentCloudService, DocumentSnapshot};
use flowy_error::{FlowyError, FlowyResult};
use flowy_folder_pub::cloud::{
  FolderCloudService, FolderCollabParams, FolderSnapshot, FullSyncCollabParams,
};
use flowy_folder_pub::entities::PublishPayload;
use flowy_search_pub::cloud::SearchCloudService;
use flowy_server_pub::af_cloud_config::AFCloudConfiguration;
use flowy_server_pub::guest_dto::{
  RevokeSharedViewAccessRequest, ShareViewWithGuestRequest, SharedViewDetails, SharedViews,
};
use flowy_server_pub::WorkspaceMemberProfile;
use flowy_storage_pub::cloud::{ObjectIdentity, ObjectValue, StorageCloudService};
use flowy_storage_pub::storage::{CompletedPartRequest, CreateUploadResponse, UploadPartResponse};
use flowy_user_pub::cloud::{
  UserAuthService, UserBillingService, UserCollabService, UserProfileService, UserServerProvider,
  UserWorkspaceService,
};
use flowy_user_pub::entities::{AuthProvider, UserTokenState, UserWorkspace, WorkspaceType};
use lib_infra::async_trait::async_trait;
use std::path::Path;
use std::sync::atomic::Ordering;
use std::sync::Arc;
use tokio_stream::wrappers::WatchStream;
use tracing::{debug, info};
use uuid::Uuid;

#[async_trait]
impl StorageCloudService for ServerProvider {
  async fn get_object_url(&self, object_id: ObjectIdentity) -> Result<String, FlowyError> {
    let storage = self
      .get_server()?
      .file_storage()
      .ok_or(FlowyError::internal())?;
    storage.get_object_url(object_id).await
  }

  async fn put_object(&self, url: String, val: ObjectValue) -> Result<(), FlowyError> {
    let storage = self
      .get_server()?
      .file_storage()
      .ok_or(FlowyError::internal())?;
    storage.put_object(url, val).await
  }

  async fn delete_object(&self, url: &str) -> Result<(), FlowyError> {
    let storage = self
      .get_server()?
      .file_storage()
      .ok_or(FlowyError::internal())?;
    storage.delete_object(url).await
  }

  async fn get_object(&self, url: String) -> Result<ObjectValue, FlowyError> {
    let storage = self
      .get_server()?
      .file_storage()
      .ok_or(FlowyError::internal())?;
    storage.get_object(url).await
  }

  async fn get_object_url_v1(
    &self,
    workspace_id: &Uuid,
    parent_dir: &str,
    file_id: &str,
  ) -> FlowyResult<String> {
    let server = self.get_server()?;
    let storage = server.file_storage().ok_or(FlowyError::internal())?;
    storage
      .get_object_url_v1(workspace_id, parent_dir, file_id)
      .await
  }

  async fn parse_object_url_v1(&self, url: &str) -> Option<(Uuid, String, String)> {
    self
      .get_server()
      .ok()?
      .file_storage()?
      .parse_object_url_v1(url)
      .await
  }

  async fn create_upload(
    &self,
    workspace_id: &Uuid,
    parent_dir: &str,
    file_id: &str,
    content_type: &str,
    file_size: u64,
  ) -> Result<CreateUploadResponse, FlowyError> {
    let server = self.get_server()?;
    let storage = server.file_storage().ok_or(FlowyError::internal())?;
    storage
      .create_upload(workspace_id, parent_dir, file_id, content_type, file_size)
      .await
  }

  async fn upload_part(
    &self,
    workspace_id: &Uuid,
    parent_dir: &str,
    upload_id: &str,
    file_id: &str,
    part_number: i32,
    body: Vec<u8>,
  ) -> Result<UploadPartResponse, FlowyError> {
    let server = self.get_server();
    let storage = server?.file_storage().ok_or(FlowyError::internal())?;
    storage
      .upload_part(
        workspace_id,
        parent_dir,
        upload_id,
        file_id,
        part_number,
        body,
      )
      .await
  }

  async fn complete_upload(
    &self,
    workspace_id: &Uuid,
    parent_dir: &str,
    upload_id: &str,
    file_id: &str,
    parts: Vec<CompletedPartRequest>,
  ) -> Result<(), FlowyError> {
    let server = self.get_server();
    let storage = server?.file_storage().ok_or(FlowyError::internal())?;
    storage
      .complete_upload(workspace_id, parent_dir, upload_id, file_id, parts)
      .await
  }
}

#[async_trait]
impl UserServerProvider for ServerProvider {
  fn set_token(&self, token: Option<String>) -> Result<(), FlowyError> {
    if let Some(token) = token {
      let server = self.get_server()?;
      debug!("Set token: {}", token);
      server.set_token(&token)?;
    }
    Ok(())
  }

  fn get_access_token(&self) -> Option<String> {
    let server = self.get_server().ok()?;
    server.get_access_token()
  }

  fn notify_access_token_invalid(&self) {
    if let Ok(server) = self.get_server() {
      tokio::spawn(async move {
        server.refresh_access_token("access token invalid").await;
      });
    }
  }

  fn set_ai_model(&self, ai_model: &str) -> Result<(), FlowyError> {
    info!("Set AI model: {}", ai_model);
    let server = self.get_server()?;
    server.set_ai_model(ai_model)?;
    Ok(())
  }

  fn subscribe_token_state(&self) -> Option<WatchStream<UserTokenState>> {
    let server = self.get_server().ok()?;
    server.subscribe_token_state()
  }

  fn set_enable_sync(&self, uid: i64, enable_sync: bool) {
    if let Ok(server) = self.get_server() {
      server.set_enable_sync(uid, enable_sync);
    }
    self.user_enable_sync.store(enable_sync, Ordering::Release);
    self.uid.store(Some(uid.into()));
  }

  /// When user login, the provider type is set by the [AuthProvider] and save to disk for next use.
  ///
  /// Each [AuthProvider] has a corresponding [AuthProvider]. The [AuthProvider] is used
  /// to create a new [AppFlowyServer] if it doesn't exist. Once the [AuthProvider] is set,
  /// it will be used when user open the app again.
  ///
  fn set_auth_provider(&self, new_auth_provider: &AuthProvider) -> FlowyResult<()> {
    let old_provider = self.get_current_auth_provider();
    if old_provider != *new_auth_provider {
      info!(
        "ServerProvider: auth provider from {:?} to {:?}",
        old_provider, new_auth_provider
      );

      self.auth_provider.store(Arc::new(*new_auth_provider));
      if let Some((auth_type, _)) = self.providers.remove(&old_provider) {
        info!("ServerProvider: remove old auth provider: {:?}", auth_type);
      }
    }

    Ok(())
  }

  fn set_network_reachable(&self, reachable: bool) {
    if let Ok(server) = self.get_server() {
      server.set_network_reachable(reachable);
    }
  }

  fn set_encrypt_secret(&self, secret: String) {
    tracing::info!("🔑Set encrypt secret");
    self.encryption.set_secret(secret);
  }

  /// Returns the [UserWorkspaceService] base on the current [AuthProvider].
  /// Creates a new [AppFlowyServer] if it doesn't exist.
  fn current_workspace_service(&self) -> Result<Arc<dyn UserWorkspaceService>, FlowyError> {
    let workspace_type = self.get_current_workspace_type()?;
    let service = self
      .get_server_from_workspace_type(workspace_type)?
      .user_service();
    Ok(service)
  }

  fn workspace_service(
    &self,
    workspace_type: WorkspaceType,
  ) -> Result<Arc<dyn UserWorkspaceService>, FlowyError> {
    let service = self
      .get_server_from_workspace_type(workspace_type)?
      .user_service();
    Ok(service)
  }

  fn auth_service(&self) -> Result<Arc<dyn UserAuthService>, FlowyError> {
    let service = self.get_server()?.auth_service();
    Ok(service)
  }

  fn user_profile_service(&self) -> Result<Arc<dyn UserProfileService>, FlowyError> {
    let auth_provider = self.get_current_auth_provider();
    let service = self
      .get_server_from_auth_provider(auth_provider)?
      .user_profile_service();
    Ok(service)
  }

  fn billing_service(&self) -> Result<Arc<dyn UserBillingService>, FlowyError> {
    let user_service = self
      .get_server_from_auth_provider(AuthProvider::Cloud)?
      .billing_service()
      .ok_or_else(FlowyError::not_support)?;
    Ok(user_service)
  }

  fn collab_service(&self) -> Result<Arc<dyn UserCollabService>, FlowyError> {
    let workspace_type = self.get_current_workspace_type()?;
    let service = self
      .get_server_from_workspace_type(workspace_type)?
      .collab_service();
    Ok(service)
  }

  fn service_url(&self) -> String {
    match self.get_current_auth_provider() {
      AuthProvider::Local => "".to_string(),
      AuthProvider::Cloud => AFCloudConfiguration::from_env()
        .map(|config| config.base_url)
        .unwrap_or_default(),
    }
  }

  fn ws_url(&self) -> String {
    match self.get_current_auth_provider() {
      AuthProvider::Local => "".to_string(),
      AuthProvider::Cloud => AFCloudConfiguration::from_env()
        .map(|config| config.ws_base_url)
        .unwrap_or_default(),
    }
  }

  async fn create_workspace(
    &self,
    workspace_name: &str,
    workspace_icon: &str,
    workspace_type: WorkspaceType,
  ) -> FlowyResult<UserWorkspace> {
    let service = self
      .get_server_from_workspace_type(workspace_type)?
      .user_service();
    service
      .create_workspace(workspace_name, workspace_icon)
      .await
  }
}

#[async_trait]
impl FolderCloudService for ServerProvider {
  async fn get_folder_snapshots(
    &self,
    workspace_id: &str,
    limit: usize,
  ) -> Result<Vec<FolderSnapshot>, FlowyError> {
    self
      .get_folder_service()?
      .get_folder_snapshots(workspace_id, limit)
      .await
  }

  async fn get_folder_doc_state(
    &self,
    workspace_id: &Uuid,
    uid: i64,
    collab_type: CollabType,
    object_id: &Uuid,
  ) -> Result<Vec<u8>, FlowyError> {
    self
      .get_folder_service()?
      .get_folder_doc_state(workspace_id, uid, collab_type, object_id)
      .await
  }

  async fn full_sync_collab_object(
    &self,
    workspace_id: &Uuid,
    params: FullSyncCollabParams,
  ) -> Result<(), FlowyError> {
    self
      .get_folder_service()?
      .full_sync_collab_object(workspace_id, params)
      .await
  }

  async fn batch_create_folder_collab_objects(
    &self,
    workspace_id: &Uuid,
    objects: Vec<FolderCollabParams>,
  ) -> Result<(), FlowyError> {
    self
      .get_folder_service()?
      .batch_create_folder_collab_objects(workspace_id, objects)
      .await
  }

  fn service_name(&self) -> String {
    self
      .get_server()
      .map(|provider| provider.folder_service().service_name())
      .unwrap_or_default()
  }

  async fn publish_view(
    &self,
    workspace_id: &Uuid,
    payload: Vec<PublishPayload>,
  ) -> Result<(), FlowyError> {
    self
      .get_folder_service()?
      .publish_view(workspace_id, payload)
      .await
  }

  async fn unpublish_views(
    &self,
    workspace_id: &Uuid,
    view_ids: Vec<Uuid>,
  ) -> Result<(), FlowyError> {
    self
      .get_folder_service()?
      .unpublish_views(workspace_id, view_ids)
      .await
  }

  async fn get_publish_info(&self, view_id: &Uuid) -> Result<PublishInfo, FlowyError> {
    self.get_folder_service()?.get_publish_info(view_id).await
  }

  async fn set_publish_name(
    &self,
    workspace_id: &Uuid,
    view_id: Uuid,
    new_name: String,
  ) -> Result<(), FlowyError> {
    self
      .get_folder_service()?
      .set_publish_name(workspace_id, view_id, new_name)
      .await
  }

  async fn set_publish_namespace(
    &self,
    workspace_id: &Uuid,
    new_namespace: String,
  ) -> Result<(), FlowyError> {
    self
      .get_folder_service()?
      .set_publish_namespace(workspace_id, new_namespace)
      .await
  }

  /// List all published views of the current workspace.
  async fn list_published_views(
    &self,
    workspace_id: &Uuid,
  ) -> Result<Vec<PublishInfoView>, FlowyError> {
    self
      .get_folder_service()?
      .list_published_views(workspace_id)
      .await
  }

  async fn get_default_published_view_info(
    &self,
    workspace_id: &Uuid,
  ) -> Result<PublishInfo, FlowyError> {
    self
      .get_folder_service()?
      .get_default_published_view_info(workspace_id)
      .await
  }

  async fn set_default_published_view(
    &self,
    workspace_id: &Uuid,
    view_id: uuid::Uuid,
  ) -> Result<(), FlowyError> {
    self
      .get_folder_service()?
      .set_default_published_view(workspace_id, view_id)
      .await
  }

  async fn remove_default_published_view(&self, workspace_id: &Uuid) -> Result<(), FlowyError> {
    self
      .get_folder_service()?
      .remove_default_published_view(workspace_id)
      .await
  }

  async fn get_publish_namespace(&self, workspace_id: &Uuid) -> Result<String, FlowyError> {
    self
      .get_folder_service()?
      .get_publish_namespace(workspace_id)
      .await
  }

  async fn import_zip(&self, file_path: &str) -> Result<(), FlowyError> {
    self.get_folder_service()?.import_zip(file_path).await
  }

  async fn share_page_with_user(
    &self,
    workspace_id: &Uuid,
    params: ShareViewWithGuestRequest,
  ) -> Result<(), FlowyError> {
    self
      .get_folder_service()?
      .share_page_with_user(workspace_id, params)
      .await
  }

  async fn revoke_shared_page_access(
    &self,
    workspace_id: &Uuid,
    view_id: &Uuid,
    params: RevokeSharedViewAccessRequest,
  ) -> Result<(), FlowyError> {
    self
      .get_folder_service()?
      .revoke_shared_page_access(workspace_id, view_id, params)
      .await
  }

  async fn get_shared_page_details(
    &self,
    workspace_id: &Uuid,
    view_id: &Uuid,
    parent_view_ids: Vec<Uuid>,
  ) -> Result<SharedViewDetails, FlowyError> {
    self
      .get_folder_service()?
      .get_shared_page_details(workspace_id, view_id, parent_view_ids)
      .await
  }

  async fn get_shared_views(&self, workspace_id: &Uuid) -> Result<SharedViews, FlowyError> {
    self
      .get_folder_service()?
      .get_shared_views(workspace_id)
      .await
  }

  async fn update_workspace_member_profile(
    &self,
    workspace_id: &Uuid,
    profile: &WorkspaceMemberProfile,
  ) -> Result<(), FlowyError> {
    self
      .get_folder_service()?
      .update_workspace_member_profile(workspace_id, profile)
      .await
  }
}

#[async_trait]
impl DatabaseCloudService for ServerProvider {
  async fn get_database_encode_collab(
    &self,
    object_id: &Uuid,
    collab_type: CollabType,
    workspace_id: &Uuid,
  ) -> Result<Option<EncodedCollab>, FlowyError> {
    self
      .get_database_service()?
      .get_database_encode_collab(object_id, collab_type, workspace_id)
      .await
  }

  async fn create_database_encode_collab(
    &self,
    object_id: &Uuid,
    collab_type: CollabType,
    workspace_id: &Uuid,
    encoded_collab: EncodedCollab,
  ) -> Result<(), FlowyError> {
    self
      .get_database_service()?
      .create_database_encode_collab(object_id, collab_type, workspace_id, encoded_collab)
      .await
  }

  async fn batch_get_database_encode_collab(
    &self,
    objects: Vec<QueryCollab>,
    workspace_id: &Uuid,
  ) -> Result<EncodeCollabByOid, FlowyError> {
    self
      .get_database_service()?
      .batch_get_database_encode_collab(objects, workspace_id)
      .await
  }

  async fn batch_create_database_encode_collab(
    &self,
    workspace_id: &Uuid,
    collabs: Vec<CreateCollabParams>,
  ) -> Result<(), FlowyError> {
    self
      .get_database_service()?
      .batch_create_database_encode_collab(workspace_id, collabs)
      .await
  }

  async fn get_database_collab_object_snapshots(
    &self,
    object_id: &Uuid,
    limit: usize,
  ) -> Result<Vec<DatabaseSnapshot>, FlowyError> {
    self
      .get_database_service()?
      .get_database_collab_object_snapshots(object_id, limit)
      .await
  }
}

#[async_trait]
impl DatabaseAIService for ServerProvider {
  async fn summary_database_row(
    &self,
    _workspace_id: &Uuid,
    _object_id: &Uuid,
    _summary_row: SummaryRowContent,
  ) -> Result<String, FlowyError> {
    let workspace_type = self.get_current_workspace_type()?;
    let server = self.get_server_from_workspace_type(workspace_type)?;
    server
      .database_ai_service()
      .ok_or_else(FlowyError::not_support)?
      .summary_database_row(_workspace_id, _object_id, _summary_row)
      .await
  }

  async fn translate_database_row(
    &self,
    _workspace_id: &Uuid,
    _translate_row: TranslateRowContent,
    _language: &str,
  ) -> Result<TranslateRowResponse, FlowyError> {
    let workspace_type = self.get_current_workspace_type()?;
    let server = self.get_server_from_workspace_type(workspace_type)?;
    server
      .database_ai_service()
      .ok_or_else(FlowyError::not_support)?
      .translate_database_row(_workspace_id, _translate_row, _language)
      .await
  }
}

#[async_trait]
impl DocumentCloudService for ServerProvider {
  async fn get_document_doc_state(
    &self,
    document_id: &Uuid,
    workspace_id: &Uuid,
  ) -> Result<Vec<u8>, FlowyError> {
    self
      .get_document_service()?
      .get_document_doc_state(document_id, workspace_id)
      .await
  }

  async fn get_document_snapshots(
    &self,
    document_id: &Uuid,
    limit: usize,
    workspace_id: &str,
  ) -> Result<Vec<DocumentSnapshot>, FlowyError> {
    self
      .get_document_service()?
      .get_document_snapshots(document_id, limit, workspace_id)
      .await
  }

  async fn get_document_data(
    &self,
    document_id: &Uuid,
    workspace_id: &Uuid,
  ) -> Result<Option<DocumentData>, FlowyError> {
    self
      .get_document_service()?
      .get_document_data(document_id, workspace_id)
      .await
  }

  async fn create_document_collab(
    &self,
    workspace_id: &Uuid,
    document_id: &Uuid,
    encoded_collab: EncodedCollab,
  ) -> Result<(), FlowyError> {
    self
      .get_document_service()?
      .create_document_collab(workspace_id, document_id, encoded_collab)
      .await
  }
}

#[async_trait]
impl ChatCloudService for ServerProvider {
  async fn create_chat(
    &self,
    uid: &i64,
    workspace_id: &Uuid,
    chat_id: &Uuid,
    rag_ids: Vec<Uuid>,
    name: &str,
    metadata: serde_json::Value,
  ) -> Result<(), FlowyError> {
    let service = self.get_chat_service()?;
    service
      .create_chat(uid, workspace_id, chat_id, rag_ids, name, metadata)
      .await
  }

  async fn create_question(
    &self,
    workspace_id: &Uuid,
    chat_id: &Uuid,
    message: &str,
    message_type: ChatMessageType,
    prompt_id: Option<String>,
    file_paths: Vec<String>,
  ) -> Result<CreatedChatMessage, FlowyError> {
    let message = message.to_string();
    self
      .get_chat_service()?
      .create_question(
        workspace_id,
        chat_id,
        &message,
        message_type,
        prompt_id,
        file_paths,
      )
      .await
  }

  async fn create_answer(
    &self,
    workspace_id: &Uuid,
    chat_id: &Uuid,
    message: &str,
    question_id: i64,
    metadata: Option<serde_json::Value>,
  ) -> Result<ChatMessage, FlowyError> {
    self
      .get_chat_service()?
      .create_answer(workspace_id, chat_id, message, question_id, metadata)
      .await
  }

  async fn stream_question(
    &self,
    workspace_id: &Uuid,
    chat_id: &Uuid,
    question_id: i64,
    format: ResponseFormat,
    ai_model: AIModel,
  ) -> Result<StreamAnswer, FlowyError> {
    self
      .get_chat_service()?
      .stream_question(workspace_id, chat_id, question_id, format, ai_model)
      .await
  }

  async fn get_chat_messages(
    &self,
    workspace_id: &Uuid,
    chat_id: &Uuid,
    offset: MessageCursor,
    limit: u64,
  ) -> Result<RepeatedChatMessage, FlowyError> {
    self
      .get_chat_service()?
      .get_chat_messages(workspace_id, chat_id, offset, limit)
      .await
  }

  async fn get_question_from_answer_id(
    &self,
    workspace_id: &Uuid,
    chat_id: &Uuid,
    answer_message_id: i64,
  ) -> Result<ChatMessage, FlowyError> {
    self
      .get_chat_service()?
      .get_question_from_answer_id(workspace_id, chat_id, answer_message_id)
      .await
  }

  async fn get_related_message(
    &self,
    workspace_id: &Uuid,
    chat_id: &Uuid,
    message_id: i64,
    ai_model: AIModel,
  ) -> Result<RepeatedRelatedQuestion, FlowyError> {
    self
      .get_chat_service()?
      .get_related_message(workspace_id, chat_id, message_id, ai_model)
      .await
  }

  async fn get_answer(
    &self,
    workspace_id: &Uuid,
    chat_id: &Uuid,
    question_id: i64,
  ) -> Result<ChatMessage, FlowyError> {
    self
      .get_chat_service()?
      .get_answer(workspace_id, chat_id, question_id)
      .await
  }

  async fn stream_complete(
    &self,
    workspace_id: &Uuid,
    params: CompleteTextParams,
    ai_model: AIModel,
  ) -> Result<StreamComplete, FlowyError> {
    self
      .get_chat_service()?
      .stream_complete(workspace_id, params, ai_model)
      .await
  }

  async fn embed_file(
    &self,
    workspace_id: &Uuid,
    file_path: &Path,
    chat_id: &Uuid,
  ) -> Result<(), FlowyError> {
    self
      .get_chat_service()?
      .embed_file(workspace_id, file_path, chat_id)
      .await
  }

  async fn get_chat_settings(
    &self,
    workspace_id: &Uuid,
    chat_id: &Uuid,
  ) -> Result<ChatSettings, FlowyError> {
    self
      .get_chat_service()?
      .get_chat_settings(workspace_id, chat_id)
      .await
  }

  async fn update_chat_settings(
    &self,
    workspace_id: &Uuid,
    chat_id: &Uuid,
    params: UpdateChatParams,
  ) -> Result<(), FlowyError> {
    self
      .get_chat_service()?
      .update_chat_settings(workspace_id, chat_id, params)
      .await
  }

  async fn get_available_models(&self, workspace_id: &Uuid) -> Result<ModelList, FlowyError> {
    self
      .get_chat_service()?
      .get_available_models(workspace_id)
      .await
  }

  async fn get_workspace_default_model(&self, workspace_id: &Uuid) -> Result<String, FlowyError> {
    self
      .get_chat_service()?
      .get_workspace_default_model(workspace_id)
      .await
  }

  async fn set_workspace_default_model(
    &self,
    workspace_id: &Uuid,
    model: &str,
  ) -> Result<(), FlowyError> {
    self
      .get_chat_service()?
      .set_workspace_default_model(workspace_id, model)
      .await
  }
}

#[async_trait]
impl SearchCloudService for ServerProvider {
  async fn document_search(
    &self,
    workspace_id: &Uuid,
    query: String,
  ) -> Result<Vec<SearchDocumentResponseItem>, FlowyError> {
    let service = self.get_search_service().await?;
    match service {
      Some(search_service) => search_service.document_search(workspace_id, query).await,
      None => Err(FlowyError::internal().with_context("SearchCloudService not found")),
    }
  }

  async fn generate_search_summary(
    &self,
    workspace_id: &Uuid,
    query: String,
    search_results: Vec<SearchResult>,
  ) -> Result<SearchSummaryResult, FlowyError> {
    let service = self.get_search_service().await?;
    match service {
      Some(search_service) => {
        search_service
          .generate_search_summary(workspace_id, query, search_results)
          .await
      },
      None => Err(FlowyError::internal().with_context("SearchCloudService not found")),
    }
  }
}
