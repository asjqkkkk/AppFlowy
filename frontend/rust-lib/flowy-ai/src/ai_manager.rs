use crate::chat::Chat;
use crate::entities::{
  AIModelPB, ChatInfoPB, ChatMessageListPB, ChatMessagePB, ChatSettingsPB,
  CustomPromptDatabaseConfigurationPB, FilePB, LocalAIModelInfoPB, LocalAIStatePB,
  ModelSelectionPB, PredefinedFormatPB, RepeatedRelatedQuestionPB, StreamMessageParams,
};
use crate::local_ai::controller::{LocalAIController, LocalAISetting};
use crate::middleware::chat_service_mw::ChatServiceMiddleware;
use flowy_ai_pub::persistence::{
  ChatTableChangeset, select_chat_metadata, select_chat_rag_ids, select_chat_summary, update_chat,
};
use std::collections::HashMap;

use dashmap::{DashMap, Entry};
use flowy_ai_pub::cloud::{AIModel, ChatCloudService, ChatSettings, UpdateChatParams};
use flowy_error::{FlowyError, FlowyResult};
use flowy_sqlite::kv::KVStorePreferences;

use crate::chat_file::ChatLocalFileStorage;
use crate::completion::AICompletion;
use crate::model_select::{
  GLOBAL_ACTIVE_MODEL_KEY, LocalAiSource, LocalModelStorageImpl, ModelSelectionControl,
  ServerAiSource, ServerModelStorageImpl, SourceKey,
};
use crate::notification::{ChatNotification, chat_notification_builder};
use flowy_ai_pub::cloud::billing_dto::PersonalPlan;
use flowy_ai_pub::persistence::{
  AFCollabMetadata, batch_insert_collab_metadata, batch_select_collab_metadata,
};
use flowy_ai_pub::user_service::AIUserService;
use flowy_storage_pub::storage::StorageService;
use lib_infra::async_trait::async_trait;
use serde_json::json;
use std::path::PathBuf;
use std::str::FromStr;
use std::sync::{Arc, Weak};
use tokio::sync::Mutex;
use tracing::{debug, error, info, instrument, trace, warn};
use uuid::Uuid;

/// AIExternalService is an interface for external services that AI plugin can interact with.
#[async_trait]
pub trait AIExternalService: Send + Sync + 'static {
  async fn query_chat_rag_ids(
    &self,
    parent_view_id: &Uuid,
    chat_id: &Uuid,
  ) -> Result<Vec<Uuid>, FlowyError>;

  async fn sync_rag_documents(
    &self,
    workspace_id: &Uuid,
    rag_ids: Vec<Uuid>,
    rag_metadata_map: HashMap<Uuid, AFCollabMetadata>,
  ) -> Result<Vec<AFCollabMetadata>, FlowyError>;

  async fn notify_did_send_message(&self, chat_id: &Uuid, message: &str) -> Result<(), FlowyError>;
}

pub struct AIManager {
  cloud_service_wm: Arc<ChatServiceMiddleware>,
  user_service: Arc<dyn AIUserService>,
  external_service: Arc<dyn AIExternalService>,
  chats: Arc<DashMap<Uuid, Arc<Chat>>>,
  store_preferences: Arc<KVStorePreferences>,
  model_control: Mutex<ModelSelectionControl>,

  pub local_ai_controller: Arc<LocalAIController>,
}
impl Drop for AIManager {
  fn drop(&mut self) {
    trace!("[Drop] drop ai manager");
  }
}

impl AIManager {
  pub fn new(
    chat_cloud_service: Arc<dyn ChatCloudService>,
    user_service: impl AIUserService,
    store_preferences: Arc<KVStorePreferences>,
    storage_service: Weak<dyn StorageService>,
    query_service: impl AIExternalService,
    local_ai: Arc<LocalAIController>,
  ) -> AIManager {
    let user_service = Arc::new(user_service);
    let external_service = Arc::new(query_service);
    let cloud_service_wm = Arc::new(ChatServiceMiddleware::new(
      user_service.clone(),
      chat_cloud_service,
      local_ai.clone(),
      storage_service,
    ));
    let mut model_control = ModelSelectionControl::new();
    model_control.set_local_storage(LocalModelStorageImpl(store_preferences.clone()));
    model_control.set_server_storage(ServerModelStorageImpl(cloud_service_wm.clone()));
    model_control.add_source(Box::new(ServerAiSource::new(cloud_service_wm.clone())));

    Self {
      cloud_service_wm,
      user_service,
      chats: Arc::new(DashMap::new()),
      local_ai_controller: local_ai,
      external_service,
      store_preferences,
      model_control: Mutex::new(model_control),
    }
  }

  pub(crate) fn ai_completion(&self) -> Arc<AICompletion> {
    let user_service = Arc::downgrade(&self.user_service);
    let cloud_service = Arc::downgrade(&self.cloud_service_wm);
    Arc::new(AICompletion::new(cloud_service, user_service))
  }

  pub async fn on_cancel_personal_subscriptions(&self, plan: &PersonalPlan) {
    match plan {
      PersonalPlan::VaultWorkspace => {
        if let Ok(workspace_id) = self.user_service.workspace_id() {
          let local_ai_controller = self.local_ai_controller.clone();
          tokio::spawn(async move {
            if local_ai_controller.is_toggle_on_workspace(&workspace_id) {
              let _ = local_ai_controller.refresh_local_ai_state(true, None).await;
            }
          });
        }
      },
    }
  }

  async fn reload_with_workspace_id(&self, workspace_id: &Uuid) {
    let result = self.user_service.validate_vault().await.unwrap_or_default();
    let is_enabled = self
      .local_ai_controller
      .is_enabled_on_workspace(
        &workspace_id.to_string(),
        result.is_vault,
        result.is_vault_enabled,
      )
      .unwrap_or(false);

    let is_toggle_on = self
      .local_ai_controller
      .is_toggle_on_workspace(workspace_id);

    let is_ready = self.local_ai_controller.is_ready().await;
    info!(
      "[AI Manager] Reloading workspace: {},  is_enabled: {},is_ready: {}",
      workspace_id, is_enabled, is_ready
    );

    let model = self.get_global_active_model().await.unwrap_or_default();

    // Shutdown AI if it's running but shouldn't be (not enabled and not in local mode)
    if is_ready && !is_enabled {
      info!("[AI Manager] Local AI is running but not enabled, shutting it down");
      let local_ai = self.local_ai_controller.clone();
      tokio::spawn(async move {
        if let Err(err) = local_ai
          .toggle_plugin(is_toggle_on, is_enabled, &result, &model)
          .await
        {
          error!("[AI Manager] failed to shutdown local AI: {:?}", err);
        }
      });
      return;
    }

    // Start AI if it's enabled but not running
    if is_enabled && !is_ready {
      info!("[AI Manager] Local AI is enabled but not running, starting it now");
      let local_ai = self.local_ai_controller.clone();
      tokio::spawn(async move {
        if let Err(err) = local_ai
          .toggle_plugin(is_toggle_on, is_enabled, &result, &model)
          .await
        {
          error!("[AI Manager] failed to start local AI: {:?}", err);
        }
      });
      return;
    }

    // Log status for other cases
    if is_ready {
      info!("[AI Manager] Local AI is already running");
    }
  }

  async fn prepare_local_ai(&self, workspace_id: &Uuid) {
    let result = self.user_service.validate_vault().await.unwrap_or_default();
    let is_enabled = self
      .local_ai_controller
      .reload_ollama_client(
        &workspace_id.to_string(),
        result.is_vault,
        result.is_vault_enabled,
      )
      .await;

    if is_enabled {
      self
        .model_control
        .lock()
        .await
        .add_source(Box::new(LocalAiSource::new(
          self.local_ai_controller.clone(),
        )));
    } else {
      self.model_control.lock().await.remove_local_source();
    }
  }

  #[instrument(skip_all, err)]
  pub async fn on_launch_if_authenticated(&self, workspace_id: &Uuid) -> Result<(), FlowyError> {
    self.prepare_local_ai(workspace_id).await;
    self.reload_with_workspace_id(workspace_id).await;
    Ok(())
  }

  pub async fn initialize_after_sign_in(&self, workspace_id: &Uuid) -> Result<(), FlowyError> {
    self.on_launch_if_authenticated(workspace_id).await?;
    Ok(())
  }

  pub async fn initialize_after_sign_up(&self, workspace_id: &Uuid) -> Result<(), FlowyError> {
    self.on_launch_if_authenticated(workspace_id).await?;
    Ok(())
  }

  #[instrument(skip_all, err)]
  pub async fn initialize_after_open_workspace(
    &self,
    workspace_id: &Uuid,
  ) -> Result<(), FlowyError> {
    self.on_launch_if_authenticated(workspace_id).await?;
    Ok(())
  }

  pub async fn open_chat(&self, chat_id: &Uuid) -> Result<(), FlowyError> {
    info!("[Chat] open chat: {}", chat_id);
    self.get_or_create_chat_instance(chat_id).await?;
    Ok(())
  }

  pub async fn close_chat(&self, chat_id: &Uuid) -> Result<(), FlowyError> {
    debug!("close chat: {}", chat_id);
    self.chats.remove(chat_id);
    self.local_ai_controller.close_chat(chat_id);
    Ok(())
  }

  pub async fn delete_chat(&self, chat_id: &Uuid) -> Result<(), FlowyError> {
    self.close_chat(chat_id).await?;
    Ok(())
  }

  pub async fn get_chat_info(&self, chat_id: &str) -> FlowyResult<ChatInfoPB> {
    let uid = self.user_service.user_id()?;
    let mut conn = self.user_service.sqlite_connection(uid)?;
    let metadata = select_chat_metadata(&mut conn, chat_id)?;
    let files = metadata
      .files
      .into_iter()
      .map(|file| FilePB {
        id: file.id,
        name: file.name,
      })
      .collect();

    Ok(ChatInfoPB {
      chat_id: chat_id.to_string(),
      files,
    })
  }

  pub async fn get_chat_attached_files(&self, chat_id: &str) -> FlowyResult<Vec<String>> {
    let chat_id = Uuid::from_str(chat_id)?;
    match self.chats.get(&chat_id) {
      None => Ok(vec![]),
      Some(chat) => chat.get_chat_attached_files().await,
    }
  }

  pub async fn get_local_model_info(&self, model_name: &str) -> FlowyResult<LocalAIModelInfoPB> {
    let info = self
      .local_ai_controller
      .get_local_model_info(model_name)
      .await?;
    dbg!(&info);

    Ok(LocalAIModelInfoPB {
      name: model_name.to_string(),
      vision: false,
    })
  }

  pub async fn restart(&self) -> FlowyResult<()> {
    let model = self.get_global_active_model().await?;
    self.local_ai_controller.restart(model).await
  }

  pub async fn get_local_ai_state(&self) -> FlowyResult<LocalAIStatePB> {
    let model = self.get_global_active_model().await?;
    let state = self
      .local_ai_controller
      .refresh_local_ai_state(false, Some(model))
      .await?;
    Ok(state)
  }

  pub async fn create_chat(
    &self,
    uid: &i64,
    parent_view_id: &Uuid,
    chat_id: &Uuid,
  ) -> Result<(), FlowyError> {
    let workspace_id = self.user_service.workspace_id()?;
    let rag_ids = if self.user_service.is_anon().await? {
      vec![]
    } else {
      self
        .external_service
        .query_chat_rag_ids(parent_view_id, chat_id)
        .await
        .unwrap_or_default()
    };

    info!("[Chat] create chat:{} with rag_ids: {:?}", chat_id, rag_ids);
    self
      .cloud_service_wm
      .create_chat(uid, &workspace_id, chat_id, rag_ids, "", json!({}))
      .await?;

    Ok(())
  }

  pub async fn stream_chat_message(
    &self,
    params: StreamMessageParams,
  ) -> Result<ChatMessagePB, FlowyError> {
    let chat = self.get_or_create_chat_instance(&params.chat_id).await?;
    let ai_model = self.get_active_model(&params.chat_id.to_string()).await;
    let question = chat.stream_chat_message(&params, ai_model).await?;
    let _ = self
      .external_service
      .notify_did_send_message(&params.chat_id, &params.message)
      .await;
    Ok(question)
  }

  pub async fn stream_regenerate_response(
    &self,
    chat_id: &Uuid,
    answer_message_id: i64,
    answer_stream_port: i64,
    format: Option<PredefinedFormatPB>,
    model: Option<AIModelPB>,
  ) -> FlowyResult<()> {
    let chat = self.get_or_create_chat_instance(chat_id).await?;
    let question_message_id = chat
      .get_question_id_from_answer_id(chat_id, answer_message_id)
      .await?;

    let model = match model {
      None => self.get_active_model(&chat_id.to_string()).await,
      Some(model) => model.into(),
    };
    chat
      .stream_regenerate_response(question_message_id, answer_stream_port, format, model)
      .await?;
    Ok(())
  }

  pub async fn update_local_ai_setting(&self, setting: LocalAISetting) -> FlowyResult<()> {
    let workspace_id = self.user_service.workspace_id()?;
    let old_settings = self.local_ai_controller.get_local_ai_setting();
    // Only restart if the server URL has changed and local AI is not running
    let need_restart = old_settings.ollama_server_url != setting.ollama_server_url;

    // Update settings first
    self
      .local_ai_controller
      .update_local_ai_setting(setting.clone())
      .await?;

    // Handle model change if needed
    info!(
      "[AI Plugin] update global active model, previous: {}, current: {}",
      old_settings.chat_model_name, setting.chat_model_name
    );
    let model = AIModel::local(setting.chat_model_name, "".to_string());
    self
      .update_selected_model(GLOBAL_ACTIVE_MODEL_KEY.to_string(), model)
      .await?;
    if need_restart {
      let model = self.get_global_active_model().await?;
      let result = self.user_service.validate_vault().await.unwrap_or_default();
      self
        .local_ai_controller
        .reload_ollama_client(
          &workspace_id.to_string(),
          result.is_vault,
          result.is_vault_enabled,
        )
        .await;
      self.local_ai_controller.restart(model).await?;
    }

    Ok(())
  }

  #[instrument(skip_all, level = "debug")]
  pub async fn update_selected_model(&self, source: String, model: AIModel) -> FlowyResult<()> {
    let workspace_id = self.user_service.workspace_id()?;
    let source_key = SourceKey::new(source.clone());
    self
      .model_control
      .lock()
      .await
      .set_active_model(&workspace_id, &source_key, model.clone())
      .await?;

    info!(
      "[Model Selection] selected model: {:?} for key:{}",
      model,
      source_key.storage_id()
    );

    let mut notify_source = vec![source.clone()];
    if source == GLOBAL_ACTIVE_MODEL_KEY {
      let ids = self
        .model_control
        .lock()
        .await
        .get_all_unset_sources()
        .await;
      info!("[Model Selection] notify all unset sources: {:?}", ids);
      notify_source.extend(ids);
    }

    trace!("[Model Selection] notify sources: {:?}", notify_source);
    for source in notify_source {
      chat_notification_builder(&source, ChatNotification::DidUpdateSelectedModel)
        .payload(AIModelPB::from(model.clone()))
        .send();
    }

    Ok(())
  }

  #[instrument(skip_all, level = "debug", err)]
  pub async fn toggle_local_ai(&self) -> FlowyResult<()> {
    let model = self.get_global_active_model().await?;
    let enabled = self.local_ai_controller.toggle_local_ai(&model).await?;

    let workspace_id = self.user_service.workspace_id()?;
    if enabled {
      self.prepare_local_ai(&workspace_id).await;
      if let Some(name) = self.local_ai_controller.get_local_chat_model() {
        let model = AIModel::local(name, "".to_string());
        info!(
          "[Model Selection] Set global active model to local ai: {}",
          model.name
        );
        if let Err(err) = self
          .update_selected_model(GLOBAL_ACTIVE_MODEL_KEY.to_string(), model)
          .await
        {
          error!(
            "[Model Selection] Failed to set global active model: {}",
            err
          );
        }
      }
      let chat_ids = self.chats.iter().map(|c| *c.key()).collect::<Vec<_>>();
      for chat_id in chat_ids {
        self.close_chat(&chat_id).await?;
        self.open_chat(&chat_id).await?;
      }
    } else {
      let mut model_control = self.model_control.lock().await;
      model_control.remove_local_source();

      let model = model_control.get_global_active_model(&workspace_id).await;
      let mut notify_source = model_control.get_all_unset_sources().await;
      notify_source.push(GLOBAL_ACTIVE_MODEL_KEY.to_string());
      drop(model_control);

      trace!(
        "[Model Selection] notify sources: {:?}, model:{}, when disable local ai",
        notify_source, model.name
      );
      for source in notify_source {
        chat_notification_builder(&source, ChatNotification::DidUpdateSelectedModel)
          .payload(AIModelPB::from(model.clone()))
          .send();
      }
    }

    Ok(())
  }

  pub async fn get_active_model(&self, source: &str) -> AIModel {
    match self.user_service.workspace_id() {
      Ok(workspace_id) => {
        let source_key = SourceKey::new(source.to_string());
        self
          .model_control
          .lock()
          .await
          .get_active_model(&workspace_id, &source_key)
          .await
      },
      Err(_) => AIModel::default(),
    }
  }

  pub async fn get_global_active_model(&self) -> FlowyResult<AIModel> {
    let workspace_id = self.user_service.workspace_id()?;
    let model_control = self.model_control.lock().await;
    let model = model_control.get_global_active_model(&workspace_id).await;
    Ok(model)
  }

  #[instrument(skip_all, level = "debug", err)]
  pub async fn get_local_available_models(
    &self,
    source: Option<String>,
  ) -> FlowyResult<ModelSelectionPB> {
    let workspace_id = self.user_service.workspace_id()?;
    let mut models = self
      .model_control
      .lock()
      .await
      .get_local_models(&workspace_id)
      .await;

    let selected_model = match source {
      None => {
        let setting = self.local_ai_controller.get_local_ai_setting();
        let selected_model = AIModel::local(setting.chat_model_name, "".to_string());
        if models.is_empty() {
          models.push(selected_model.clone());
        }
        selected_model
      },
      Some(source) => {
        let source_key = SourceKey::new(source);
        self
          .model_control
          .lock()
          .await
          .get_active_model(&workspace_id, &source_key)
          .await
      },
    };

    Ok(ModelSelectionPB {
      models: models.into_iter().map(AIModelPB::from).collect(),
      selected_model: AIModelPB::from(selected_model),
    })
  }

  pub async fn get_available_models(
    &self,
    source: String,
    setting_only: bool,
  ) -> FlowyResult<ModelSelectionPB> {
    let result = self.user_service.validate_vault().await.unwrap_or_default();
    if result.is_vault {
      debug!("[Model Selection] Vault workspace detected, using local models only");
      return self.get_local_available_models(Some(source)).await;
    }

    let workspace_id = self.user_service.workspace_id()?;
    let local_model_name = if setting_only {
      Some(
        self
          .local_ai_controller
          .get_local_ai_setting()
          .chat_model_name,
      )
    } else {
      None
    };

    let source_key = SourceKey::new(source);
    let model_control = self.model_control.lock().await;
    let active_model = model_control
      .get_active_model(&workspace_id, &source_key)
      .await;

    trace!(
      "[Model Selection] {} active model: {:?}, global model:{:?}",
      source_key.storage_id(),
      active_model,
      local_model_name
    );

    let all_models = model_control
      .get_models_with_specific_local_model(&workspace_id, local_model_name)
      .await;
    drop(model_control);

    Ok(ModelSelectionPB {
      models: all_models.into_iter().map(AIModelPB::from).collect(),
      selected_model: AIModelPB::from(active_model),
    })
  }

  pub async fn get_or_create_chat_instance(&self, chat_id: &Uuid) -> Result<Arc<Chat>, FlowyError> {
    let entry = self.chats.entry(*chat_id);
    match entry {
      Entry::Occupied(occupied) => Ok(occupied.get().clone()),
      Entry::Vacant(vacant) => {
        info!("[Chat] create chat: {}", chat_id);
        let file_storage = match self.user_service.user_data_dir() {
          Ok(root) => ChatLocalFileStorage::new(root).ok().map(Arc::new),
          Err(_) => None,
        };

        let chat = Arc::new(Chat::new(
          self.user_service.user_id()?,
          *chat_id,
          self.user_service.clone(),
          self.cloud_service_wm.clone(),
          file_storage.clone(),
        ));
        vacant.insert(chat.clone());

        if self.local_ai_controller.is_enabled().await? {
          info!("[Chat] create chat with local AI: {}", chat_id);
          let workspace_id = self.user_service.workspace_id()?;
          let rag_ids = self.get_rag_ids(chat_id).await?;

          let uid = self.user_service.user_id()?;
          let mut conn = self.user_service.sqlite_connection(uid)?;
          let summary = select_chat_summary(&mut conn, chat_id).unwrap_or_default();
          let model = self.get_active_model(&chat_id.to_string()).await;
          self
            .local_ai_controller
            .open_chat(
              &workspace_id,
              chat_id,
              &model.name,
              rag_ids,
              summary,
              file_storage,
            )
            .await?;
        }

        let user_service = self.user_service.clone();
        let cloud_service_wm = self.cloud_service_wm.clone();
        let store_preferences = self.store_preferences.clone();
        let external_service = self.external_service.clone();
        let local_ai = self.local_ai_controller.clone();
        let chat_id = *chat_id;
        tokio::spawn(async move {
          match refresh_chat_setting(
            &user_service,
            &cloud_service_wm,
            &store_preferences,
            &chat_id,
          )
          .await
          {
            Ok(settings) => {
              local_ai.set_rag_ids(&chat_id, &settings.rag_ids).await;
              let rag_ids = settings
                .rag_ids
                .into_iter()
                .flat_map(|r| Uuid::from_str(&r).ok())
                .collect();
              let _ = sync_chat_documents(user_service, external_service, rag_ids).await;
            },
            Err(err) => {
              error!("failed to refresh chat settings: {}", err);
            },
          }
        });

        Ok(chat)
      },
    }
  }

  /// Load chat messages for a given `chat_id`.
  ///
  /// 1. When opening a chat:
  ///    - Loads local chat messages.
  ///    - `after_message_id` and `before_message_id` are `None`.
  ///    - Spawns a task to load messages from the remote server, notifying the user when the remote messages are loaded.
  ///
  /// 2. Loading more messages in an existing chat with `after_message_id`:
  ///    - `after_message_id` is the last message ID in the current chat messages.
  ///
  /// 3. Loading more messages in an existing chat with `before_message_id`:
  ///    - `before_message_id` is the first message ID in the current chat messages.
  ///
  /// 4. `after_message_id` and `before_message_id` cannot be specified at the same time.
  pub async fn load_prev_chat_messages(
    &self,
    chat_id: &Uuid,
    limit: u64,
    before_message_id: Option<i64>,
  ) -> Result<ChatMessageListPB, FlowyError> {
    let chat = self.get_or_create_chat_instance(chat_id).await?;
    let list = chat
      .load_prev_chat_messages(limit, before_message_id)
      .await?;
    Ok(list)
  }

  pub async fn load_latest_chat_messages(
    &self,
    chat_id: &Uuid,
    limit: u64,
    after_message_id: Option<i64>,
  ) -> Result<ChatMessageListPB, FlowyError> {
    let chat = self.get_or_create_chat_instance(chat_id).await?;
    let list = chat
      .load_latest_chat_messages(limit, after_message_id)
      .await?;
    Ok(list)
  }

  pub async fn get_related_questions(
    &self,
    chat_id: &Uuid,
    message_id: i64,
  ) -> Result<RepeatedRelatedQuestionPB, FlowyError> {
    let chat = self.get_or_create_chat_instance(chat_id).await?;
    let ai_model = self.get_active_model(&chat_id.to_string()).await;
    let resp = chat.get_related_question(message_id, ai_model).await?;
    Ok(resp)
  }

  pub async fn generate_answer(
    &self,
    chat_id: &Uuid,
    question_message_id: i64,
  ) -> Result<ChatMessagePB, FlowyError> {
    let chat = self.get_or_create_chat_instance(chat_id).await?;
    let resp = chat.generate_answer(question_message_id).await?;
    Ok(resp)
  }

  pub async fn stop_stream(&self, chat_id: &Uuid) -> Result<(), FlowyError> {
    let chat = self.get_or_create_chat_instance(chat_id).await?;
    chat.stop_stream_message().await;
    Ok(())
  }

  pub async fn chat_with_file(&self, chat_id: &Uuid, file_path: PathBuf) -> FlowyResult<()> {
    let chat = self.get_or_create_chat_instance(chat_id).await?;
    chat.index_file(file_path).await?;
    Ok(())
  }

  pub async fn get_rag_ids(&self, chat_id: &Uuid) -> FlowyResult<Vec<String>> {
    let uid = self.user_service.user_id()?;
    let mut conn = self.user_service.sqlite_connection(uid)?;
    match select_chat_rag_ids(&mut conn, &chat_id.to_string()) {
      Ok(ids) => {
        return Ok(ids);
      },
      Err(_) => {
        // we no long use store_preferences to store chat settings
        warn!("[Chat] failed to get chat rag ids from sqlite, try to get from store_preferences");
        if let Some(settings) = self
          .store_preferences
          .get_object::<ChatSettings>(&setting_store_key(chat_id))
        {
          return Ok(settings.rag_ids);
        }
      },
    }

    let settings = refresh_chat_setting(
      &self.user_service,
      &self.cloud_service_wm,
      &self.store_preferences,
      chat_id,
    )
    .await?;
    Ok(settings.rag_ids)
  }

  pub async fn update_rag_ids(&self, chat_id: &Uuid, rag_ids: Vec<String>) -> FlowyResult<()> {
    info!("[Chat] update chat:{} rag ids: {:?}", chat_id, rag_ids);
    let workspace_id = self.user_service.workspace_id()?;
    let update_setting = UpdateChatParams {
      name: None,
      metadata: None,
      rag_ids: Some(rag_ids.clone()),
    };
    self
      .cloud_service_wm
      .update_chat_settings(&workspace_id, chat_id, update_setting)
      .await?;

    let uid = self.user_service.user_id()?;
    let conn = self.user_service.sqlite_connection(uid)?;
    update_chat(
      conn,
      ChatTableChangeset::rag_ids(chat_id.to_string(), rag_ids.clone()),
    )?;

    let user_service = self.user_service.clone();
    let external_service = self.external_service.clone();
    self
      .local_ai_controller
      .set_rag_ids(chat_id, &rag_ids)
      .await;

    let rag_ids = rag_ids
      .into_iter()
      .flat_map(|r| Uuid::from_str(&r).ok())
      .collect();
    sync_chat_documents(user_service, external_service, rag_ids).await?;
    Ok(())
  }

  pub async fn get_custom_prompt_database_configuration(
    &self,
  ) -> FlowyResult<Option<CustomPromptDatabaseConfigurationPB>> {
    let view_id = self
      .store_preferences
      .get_object::<CustomPromptDatabaseConfigurationPB>(CUSTOM_PROMPT_DATABASE_CONFIGURATION_KEY);

    Ok(view_id)
  }

  pub async fn set_custom_prompt_database_configuration(
    &self,
    config: CustomPromptDatabaseConfigurationPB,
  ) -> FlowyResult<()> {
    if let Err(err) = self
      .store_preferences
      .set_object(CUSTOM_PROMPT_DATABASE_CONFIGURATION_KEY, &config)
    {
      error!(
        "failed to set custom prompt database configuration settings: {}",
        err
      );
    }

    Ok(())
  }
}

async fn sync_chat_documents(
  user_service: Arc<dyn AIUserService>,
  external_service: Arc<dyn AIExternalService>,
  rag_ids: Vec<Uuid>,
) -> FlowyResult<()> {
  if rag_ids.is_empty() {
    return Ok(());
  }

  let uid = user_service.user_id()?;
  let conn = user_service.sqlite_connection(uid)?;
  let metadata_map = batch_select_collab_metadata(conn, &rag_ids)?;

  let user_service = user_service.clone();
  tokio::spawn(async move {
    if let Ok(workspace_id) = user_service.workspace_id() {
      if let Ok(metadatas) = external_service
        .sync_rag_documents(&workspace_id, rag_ids, metadata_map)
        .await
      {
        if let Ok(uid) = user_service.user_id() {
          if let Ok(conn) = user_service.sqlite_connection(uid) {
            batch_insert_collab_metadata(conn, &metadatas).unwrap();
          }
        }
      }
    }
  });

  Ok(())
}

async fn refresh_chat_setting(
  user_service: &Arc<dyn AIUserService>,
  cloud_service: &Arc<ChatServiceMiddleware>,
  store_preferences: &Arc<KVStorePreferences>,
  chat_id: &Uuid,
) -> FlowyResult<ChatSettings> {
  let workspace_id = user_service.workspace_id()?;
  let settings = cloud_service
    .get_chat_settings(&workspace_id, chat_id)
    .await?;

  debug!("[Chat] refresh chat:{} setting:{:?}", chat_id, settings);
  if let Err(err) = store_preferences.set_object(&setting_store_key(chat_id), &settings) {
    error!("failed to set chat settings: {}", err);
  }

  chat_notification_builder(chat_id.to_string(), ChatNotification::DidUpdateChatSettings)
    .payload(ChatSettingsPB {
      rag_ids: settings.rag_ids.clone(),
    })
    .send();

  Ok(settings)
}

fn setting_store_key(chat_id: &Uuid) -> String {
  format!("chat_settings_{}", chat_id)
}

const CUSTOM_PROMPT_DATABASE_CONFIGURATION_KEY: &str = "custom_prompt_database_config";
