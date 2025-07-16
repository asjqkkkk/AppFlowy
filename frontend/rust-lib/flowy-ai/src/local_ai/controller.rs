use crate::entities::{LackOfAIResourcePB, LocalAIStatePB};
use crate::local_ai::resource::{LLMResourceService, LocalAIResourceController};
use crate::notification::{
  APPFLOWY_AI_NOTIFICATION_KEY, ChatNotification, chat_notification_builder,
};
use anyhow::Error;
use flowy_error::{FlowyError, FlowyResult};
use flowy_sqlite::kv::KVStorePreferences;
use lib_infra::async_trait::async_trait;

use crate::chat_file::ChatLocalFileStorage;
use crate::embeddings::indexer::LocalEmbeddingModel;
use crate::local_ai::chat::llm::LocalLLMController;
use crate::local_ai::chat::{LLMChatController, LLMChatInfo};
use crate::local_ai::util::{get_embedding_model_dimension, is_model_support_vision};
use arc_swap::ArcSwapOption;
use flowy_ai_pub::cloud::AIModel;
use flowy_ai_pub::entities::EmbeddingDimension;
use flowy_ai_pub::persistence::{
  LocalAIModelTable, ModelType, select_local_ai_model, upsert_local_ai_model,
};
use flowy_ai_pub::user_service::{AIUserService, ValidateVaultResult};
use lib_infra::util::get_operating_system;
use ollama_rs::Ollama;
use ollama_rs::generation::embeddings::request::{EmbeddingsInput, GenerateEmbeddingsRequest};
use ollama_rs::models::ModelInfo;
use serde::{Deserialize, Serialize};
use std::ops::Deref;
use std::sync::{Arc, Weak};
use tracing::{debug, error, info, instrument, trace, warn};
use uuid::Uuid;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct LocalAISetting {
  pub ollama_server_url: String,
  pub chat_model_name: String,
  pub embedding_model_name: String,
}

fn default_embedding_dimension() -> usize {
  EmbeddingDimension::Dim768.size()
}

impl Default for LocalAISetting {
  fn default() -> Self {
    Self {
      ollama_server_url: "http://localhost:11434".to_string(),
      chat_model_name: "gemma3:4b".to_string(),
      embedding_model_name: "nomic-embed-text:latest".to_string(),
    }
  }
}

const LOCAL_AI_SETTING_KEY: &str = "appflowy_local_ai_setting:v1";

pub struct LocalAIController {
  chat_controller: LLMChatController,
  resource: Arc<LocalAIResourceController>,
  store_preferences: Weak<KVStorePreferences>,
  user_service: Arc<dyn AIUserService>,
  pub(crate) llm_controller: ArcSwapOption<LocalLLMController>,
}

impl Deref for LocalAIController {
  type Target = LLMChatController;

  fn deref(&self) -> &Self::Target {
    &self.chat_controller
  }
}

impl LocalAIController {
  pub fn new(
    store_preferences: Weak<KVStorePreferences>,
    user_service: Arc<dyn AIUserService>,
  ) -> Self {
    debug!(
      "[Local AI] init local ai controller, thread: {:?}",
      std::thread::current().id()
    );

    // Create the core plugin and resource controller
    let res_impl = LLMResourceServiceImpl {
      store_preferences: store_preferences.clone(),
    };
    let local_ai_resource = Arc::new(LocalAIResourceController::new(
      user_service.clone(),
      res_impl,
    ));

    let llm_controller = ArcSwapOption::default();
    let chat_controller = LLMChatController::new(Arc::downgrade(&user_service));
    Self {
      chat_controller,
      resource: local_ai_resource,
      store_preferences,
      user_service,
      llm_controller,
    }
  }

  pub async fn reload_ollama_client(
    &self,
    workspace_id: &str,
    is_vault: bool,
    is_vault_enabled: bool,
    old_setting: LocalAISetting,
  ) -> bool {
    if !self
      .is_enabled_on_workspace(workspace_id, is_vault, is_vault_enabled)
      .unwrap_or(false)
    {
      #[cfg(any(target_os = "windows", target_os = "macos", target_os = "linux"))]
      {
        trace!("[Local AI] local ai is disabled, clear ollama client",);
        let shared = crate::embeddings::context::EmbedContext::shared();
        shared.set_llm(None);
        self.llm_controller.store(None);
      }
      return false;
    }

    let setting = self.resource.get_llm_setting();
    info!(
      "Current local ai setting: {:?}, previous:{:?}",
      setting, old_setting
    );

    if let Some(llm_controller) = self.llm_controller.load_full() {
      if !llm_controller.is_setting_changed(&old_setting) {
        info!("[Local AI] ollama client is already initialized");
        return true;
      }
    }

    match Ollama::try_new(&setting.ollama_server_url).map(Arc::new) {
      Ok(new_ollama) => {
        let dimension = get_embedding_model_dimension(&new_ollama, &setting.embedding_model_name)
          .await
          .unwrap_or_else(|| {
            error!(
              "[Local AI] failed to get embedding model dimension for {}, using default dimension",
              setting.embedding_model_name
            );
            default_embedding_dimension()
          });
        let embed_model = LocalEmbeddingModel::from((setting.embedding_model_name, dimension));
        let local_llm_controller = Arc::new(LocalLLMController::new(
          new_ollama,
          setting.chat_model_name.clone(),
          embed_model,
        ));

        #[cfg(any(target_os = "windows", target_os = "macos", target_os = "linux"))]
        {
          info!("[Local AI] reload ollama client successfully");
          let shared = crate::embeddings::context::EmbedContext::shared();
          shared.set_llm(Some(local_llm_controller.clone()));
          if let Some(vc) = shared.get_vector_db() {
            self
              .chat_controller
              .initialize(Arc::downgrade(&local_llm_controller), Arc::downgrade(&vc))
              .await;
          } else {
            error!("[Local AI] vector db is not initialized");
          }
        }
        self
          .llm_controller
          .store(Some(local_llm_controller.clone()));
        true
      },
      Err(err) => {
        error!(
          "[Local AI] failed to create ollama client: {:?}, thread: {:?}",
          err,
          std::thread::current().id()
        );
        false
      },
    }
  }

  fn upgrade_store_preferences(&self) -> FlowyResult<Arc<KVStorePreferences>> {
    self
      .store_preferences
      .upgrade()
      .ok_or_else(|| FlowyError::internal().with_context("Store preferences is dropped"))
  }

  /// Indicate whether the local AI is enabled.
  /// AppFlowy store the value in local storage isolated by workspace id. Each workspace can have
  /// different settings.
  pub async fn is_enabled(&self) -> FlowyResult<bool> {
    let workspace_id = self.user_service.workspace_id()?;
    let result = self.user_service.validate_vault().await.unwrap_or_default();
    self.is_enabled_on_workspace(
      &workspace_id.to_string(),
      result.is_vault,
      result.is_vault_enabled,
    )
  }

  pub fn is_enabled_on_workspace(
    &self,
    workspace_id: &str,
    is_vault: bool,
    is_vault_enabled: bool,
  ) -> FlowyResult<bool> {
    debug!(
      "[Local AI] check local ai enabled for workspace: {}, is_vault: {}, is_vault_enabled:{}",
      workspace_id, is_vault, is_vault_enabled
    );
    if !get_operating_system().is_desktop() {
      return Ok(false);
    }

    if is_vault && !is_vault_enabled {
      info!("Current workspace is vault, but vault is not enabled, skip local AI");
      return Err(FlowyError::feature_not_available().with_context("Vault is not enabled"));
    }

    let key = local_ai_enabled_key(workspace_id);
    match self.upgrade_store_preferences() {
      Ok(store) => Ok(store.get_bool(&key).unwrap_or(false)),
      Err(_) => Ok(false),
    }
  }

  pub fn is_toggle_on_workspace(&self, workspace_id: &Uuid) -> bool {
    if !get_operating_system().is_desktop() {
      return false;
    }

    let key = local_ai_enabled_key(&workspace_id.to_string());
    match self.upgrade_store_preferences() {
      Ok(store) => store.get_bool(&key).unwrap_or(false),
      Err(_) => false,
    }
  }

  pub fn set_toggle_on_workspace(&self, workspace_id: &str, is_on: bool) {
    let key = local_ai_enabled_key(workspace_id);
    if let Ok(store) = self.upgrade_store_preferences() {
      store.set_bool(&key, is_on).unwrap_or_else(|e| {
        error!(
          "[Local AI] failed to set toggle on workspace: {}, error: {}",
          workspace_id, e
        );
      });
    }
  }

  pub fn get_local_chat_model(&self) -> Option<String> {
    Some(self.resource.get_llm_setting().chat_model_name)
  }

  pub async fn get_local_model_info(&self, model_name: &str) -> FlowyResult<ModelInfo> {
    match self.llm_controller.load_full() {
      None => Err(FlowyError::internal().with_context("ollama is not initialized")),
      Some(ollama) => {
        let info = ollama.show_model_info(model_name.to_string()).await?;
        Ok(info)
      },
    }
  }

  pub async fn is_model_support_vision(&self, model: &AIModel) -> bool {
    if model.is_local {
      match self.get_local_model_info(&model.name).await {
        Ok(model_info) => {
          // Check if the model_info contains any vision-related keys
          let has_vision = is_model_support_vision(&model_info);
          debug!(
            "[Local AI] model {} vision support: {}, model_info: {:?}",
            model.name, has_vision, model_info.model_info
          );
          has_vision
        },
        Err(err) => {
          warn!(
            "[Local AI] failed to get model info for {}: {:?}",
            model.name, err
          );
          false
        },
      }
    } else {
      true
    }
  }

  pub async fn open_chat(
    &self,
    workspace_id: &Uuid,
    chat_id: &Uuid,
    model: &str,
    rag_ids: Vec<String>,
    summary: String,
    file_storage: Option<Arc<ChatLocalFileStorage>>,
  ) -> FlowyResult<()> {
    let info = LLMChatInfo {
      chat_id: *chat_id,
      workspace_id: *workspace_id,
      model: model.to_string(),
      rag_ids,
      summary,
    };
    self.chat_controller.open_chat(info, file_storage).await?;
    Ok(())
  }

  pub fn close_chat(&self, chat_id: &Uuid) {
    info!("[Chat] notify close chat: {}", chat_id);
    self.chat_controller.close_chat(chat_id);
  }

  pub fn get_local_ai_setting(&self) -> LocalAISetting {
    self.resource.get_llm_setting()
  }

  pub async fn get_all_chat_local_models(&self) -> Vec<AIModel> {
    self
      .get_filtered_local_models(|name| !name.contains("embed"))
      .await
  }

  pub async fn get_all_embedded_local_models(&self) -> Vec<AIModel> {
    self
      .get_filtered_local_models(|name| name.contains("embed"))
      .await
  }

  // Helper function to avoid code duplication in model retrieval
  async fn get_filtered_local_models<F>(&self, filter_fn: F) -> Vec<AIModel>
  where
    F: Fn(&str) -> bool,
  {
    match self.llm_controller.load_full() {
      None => vec![],
      Some(ollama) => ollama
        .list_local_models()
        .await
        .map(|models| {
          models
            .into_iter()
            .filter(|m| filter_fn(&m.name.to_lowercase()))
            .map(|m| AIModel::local(m.name, String::new()))
            .collect()
        })
        .unwrap_or_default(),
    }
  }

  pub async fn check_model_type(&self, model_name: &str) -> FlowyResult<ModelType> {
    let uid = self.user_service.user_id()?;
    let mut conn = self.user_service.sqlite_connection(uid)?;
    match select_local_ai_model(&mut conn, model_name) {
      None => {
        let local_controller = self
          .llm_controller
          .load_full()
          .ok_or_else(|| FlowyError::local_ai().with_context("ollama is not initialized"))?;

        let request = GenerateEmbeddingsRequest::new(
          model_name.to_string(),
          EmbeddingsInput::Single("Hello".to_string()),
        );

        let model_type = match local_controller.generate_embeddings(request).await {
          Ok(value) => {
            if value.embeddings.is_empty() {
              ModelType::Chat
            } else {
              ModelType::Embedding
            }
          },
          Err(_) => ModelType::Chat,
        };

        upsert_local_ai_model(
          &mut conn,
          &LocalAIModelTable {
            name: model_name.to_string(),
            model_type: model_type as i16,
          },
        )?;
        Ok(model_type)
      },
      Some(r) => Ok(ModelType::from(r.model_type)),
    }
  }

  pub async fn update_local_ai_setting(&self, setting: LocalAISetting) -> FlowyResult<()> {
    info!(
      "[Local AI] update local ai setting: {:?}, thread: {:?}",
      setting,
      std::thread::current().id()
    );
    self.resource.set_llm_setting(setting).await?;
    Ok(())
  }

  #[instrument(level = "debug", skip_all)]
  pub async fn refresh_local_ai_state(
    &self,
    notify: bool,
    model: Option<AIModel>,
  ) -> FlowyResult<LocalAIStatePB> {
    let workspace_id = self.user_service.workspace_id()?;
    let result = self.user_service.validate_vault().await?;
    let toggle_on = self.is_toggle_on_workspace(&workspace_id);
    let lack_of_resource = self.resource.get_lack_of_resource().await;
    let vision_enabled = match model {
      None => false,
      Some(model) => self.is_model_support_vision(&model).await,
    };
    let state = LocalAIStatePB {
      toggle_on,
      is_vault: result.is_vault,
      enabled: result.can_use_local_ai(),
      lack_of_resource,
      is_ready: self.is_ready().await,
      vision_enabled,
    };
    if notify {
      chat_notification_builder(
        APPFLOWY_AI_NOTIFICATION_KEY,
        ChatNotification::UpdateLocalAIState,
      )
      .payload(state.clone())
      .send();
    }

    Ok(state)
  }

  #[instrument(level = "debug", skip_all)]
  pub async fn restart(&self, model: AIModel) -> FlowyResult<()> {
    if let Some(lack_of_resource) = check_resources(&self.resource).await {
      let result = self.user_service.validate_vault().await.unwrap_or_default();
      let vision_enabled = self.is_model_support_vision(&model).await;
      chat_notification_builder(
        APPFLOWY_AI_NOTIFICATION_KEY,
        ChatNotification::UpdateLocalAIState,
      )
      .payload(LocalAIStatePB {
        toggle_on: true,
        is_vault: result.is_vault,
        enabled: result.can_use_local_ai(),
        lack_of_resource: Some(lack_of_resource),
        is_ready: self.is_ready().await,
        vision_enabled,
      })
      .send();
    }
    Ok(())
  }

  pub fn get_model_storage_directory(&self) -> FlowyResult<String> {
    self
      .resource
      .user_model_folder()
      .map(|path| path.to_string_lossy().to_string())
  }

  pub async fn toggle_local_ai(&self, model: &AIModel) -> FlowyResult<bool> {
    let workspace_id = self.user_service.workspace_id()?;
    let result = self.user_service.validate_vault().await.unwrap_or_default();
    let is_toggle_on = !self.is_toggle_on_workspace(&workspace_id);
    self.set_toggle_on_workspace(&workspace_id.to_string(), is_toggle_on);
    self
      .toggle_plugin(is_toggle_on, result.can_use_local_ai(), &result, model)
      .await?;
    Ok(is_toggle_on)
  }

  #[instrument(level = "debug", skip_all)]
  pub(crate) async fn toggle_plugin(
    &self,
    toggle_on: bool,
    enabled: bool,
    vault_result: &ValidateVaultResult,
    model: &AIModel,
  ) -> FlowyResult<()> {
    let lack_of_resource = if enabled {
      check_resources(&self.resource).await
    } else {
      None
    };

    let vision_enabled = self.is_model_support_vision(model).await;
    chat_notification_builder(
      APPFLOWY_AI_NOTIFICATION_KEY,
      ChatNotification::UpdateLocalAIState,
    )
    .payload(LocalAIStatePB {
      toggle_on,
      is_vault: vault_result.is_vault,
      enabled: vault_result.can_use_local_ai(),
      lack_of_resource,
      is_ready: self.is_ready().await,
      vision_enabled,
    })
    .send();
    Ok(())
  }
}

async fn check_resources(
  llm_resource: &Arc<LocalAIResourceController>,
) -> Option<LackOfAIResourcePB> {
  let lack_of_resource = llm_resource.get_lack_of_resource().await;
  if let Some(lack_of_resource) = lack_of_resource {
    info!(
      "[Local AI] lack of resource: {:?} to initialize plugin, thread: {:?}",
      lack_of_resource,
      std::thread::current().id()
    );

    chat_notification_builder(
      APPFLOWY_AI_NOTIFICATION_KEY,
      ChatNotification::LocalAIResourceUpdated,
    )
    .payload(lack_of_resource.clone())
    .send();
    return Some(lack_of_resource);
  }
  None
}

pub struct LLMResourceServiceImpl {
  store_preferences: Weak<KVStorePreferences>,
}

impl LLMResourceServiceImpl {
  fn upgrade_store_preferences(&self) -> FlowyResult<Arc<KVStorePreferences>> {
    self
      .store_preferences
      .upgrade()
      .ok_or_else(|| FlowyError::internal().with_context("Store preferences is dropped"))
  }
}
#[async_trait]
impl LLMResourceService for LLMResourceServiceImpl {
  fn store_setting(&self, setting: LocalAISetting) -> Result<(), Error> {
    let store_preferences = self.upgrade_store_preferences()?;
    store_preferences.set_object(LOCAL_AI_SETTING_KEY, &setting)?;
    Ok(())
  }

  fn retrieve_setting(&self) -> Option<LocalAISetting> {
    let store_preferences = self.upgrade_store_preferences().ok()?;
    store_preferences.get_object::<LocalAISetting>(LOCAL_AI_SETTING_KEY)
  }
}

const APPFLOWY_LOCAL_AI_ENABLED: &str = "appflowy_local_ai_enabled";
fn local_ai_enabled_key(workspace_id: &str) -> String {
  format!("{}:{}", APPFLOWY_LOCAL_AI_ENABLED, workspace_id)
}
