pub mod chains;
mod format_prompt;
pub mod llm;
pub mod llm_chat;
pub mod retriever;
mod summary_memory;

use crate::SqliteVectorStore;
use crate::chat_file::ChatLocalFileStorage;
use crate::local_ai::chat::llm::LLMOllama;
use crate::local_ai::chat::llm_chat::{LLMChat, StreamQuestionOptions};
use crate::local_ai::chat::retriever::RetrieverStore;
use crate::local_ai::completion::chain::CompletionChain;
use crate::local_ai::database::summary::DatabaseSummaryChain;
use crate::local_ai::database::translate::DatabaseTranslateChain;
use dashmap::{DashMap, Entry};
use flowy_ai_pub::cloud::ai_dto::{TranslateRowData, TranslateRowResponse};
use flowy_ai_pub::cloud::{
  CompleteTextParams, CompletionType, ResponseFormat, StreamAnswer, StreamComplete,
};
use flowy_ai_pub::persistence::select_message_pair;
use flowy_ai_pub::user_service::AIUserService;
use flowy_database_pub::cloud::{SummaryRowContent, TranslateRowContent};
use flowy_error::{FlowyError, FlowyResult};
use futures_util::StreamExt;
use ollama_rs::Ollama;
use std::path::PathBuf;
use std::sync::{Arc, Weak};
use tokio::sync::RwLock;
use tracing::{debug, info, instrument, warn};
use uuid::Uuid;

type OllamaClientRef = Arc<RwLock<Option<Weak<Ollama>>>>;

pub struct LLMChatInfo {
  pub chat_id: Uuid,
  pub workspace_id: Uuid,
  pub model: String,
  pub rag_ids: Vec<String>,
  pub summary: String,
}

pub type RetrieversSources = RwLock<Vec<Arc<dyn RetrieverStore>>>;

pub struct LLMChatController {
  chat_by_id: DashMap<Uuid, Arc<RwLock<LLMChat>>>,
  store: RwLock<Option<SqliteVectorStore>>,
  client: OllamaClientRef,
  user_service: Weak<dyn AIUserService>,
  retriever_sources: RetrieversSources,
}
impl LLMChatController {
  pub fn new(user_service: Weak<dyn AIUserService>) -> Self {
    Self {
      store: RwLock::new(None),
      chat_by_id: DashMap::new(),
      client: Default::default(),
      user_service,
      retriever_sources: Default::default(),
    }
  }

  pub async fn set_retriever_sources(&self, sources: Vec<Arc<dyn RetrieverStore>>) {
    *self.retriever_sources.write().await = sources;
  }

  pub async fn is_ready(&self) -> bool {
    self.client.read().await.is_some()
  }

  #[cfg(any(target_os = "windows", target_os = "macos", target_os = "linux"))]
  pub async fn initialize(
    &self,
    ollama: Weak<Ollama>,
    vector_db: Weak<flowy_sqlite_vec::db::VectorSqliteDB>,
  ) {
    let store = SqliteVectorStore::new(ollama.clone(), vector_db);
    *self.client.write().await = Some(ollama);
    *self.store.write().await = Some(store);
  }

  pub async fn set_rag_ids(&self, chat_id: &Uuid, rag_ids: &[String]) {
    if let Some(chat) = self.get_chat(chat_id) {
      debug!(
        "[Chat] Setting RAG IDs for chat:{}, rag_ids:{:?}",
        chat_id, rag_ids
      );
      chat.write().await.set_rag_ids(rag_ids.to_vec());
    }
  }

  async fn create_chat_if_not_exist(
    &self,
    info: LLMChatInfo,
    file_storage: Option<Arc<ChatLocalFileStorage>>,
  ) -> FlowyResult<()> {
    let store = self.store.read().await.clone();
    let client = self
      .client
      .read()
      .await
      .as_ref()
      .ok_or_else(|| FlowyError::local_ai().with_context("Ollama client not initialized"))?
      .upgrade()
      .ok_or_else(|| FlowyError::local_ai().with_context("Ollama client has been dropped"))?
      .clone();
    let entry = self.chat_by_id.entry(info.chat_id);
    let retriever_sources = self
      .retriever_sources
      .read()
      .await
      .iter()
      .map(Arc::downgrade)
      .collect();
    if let Entry::Vacant(e) = entry {
      info!("[Chat] Creating new chat with id: {}", info.chat_id);
      let chat = LLMChat::new(
        info,
        client,
        store,
        Some(self.user_service.clone()),
        retriever_sources,
        file_storage,
      )?;
      e.insert(Arc::new(RwLock::new(chat)));
    }
    Ok(())
  }

  pub async fn open_chat(
    &self,
    info: LLMChatInfo,
    file_storage: Option<Arc<ChatLocalFileStorage>>,
  ) -> FlowyResult<()> {
    let _ = self.create_chat_if_not_exist(info, file_storage).await;
    Ok(())
  }

  pub fn close_chat(&self, chat_id: &Uuid) {
    info!("[Chat] Closing chat with id: {}", chat_id);
    self.chat_by_id.remove(chat_id);
  }

  pub fn get_chat(&self, chat_id: &Uuid) -> Option<Arc<RwLock<LLMChat>>> {
    self.chat_by_id.get(chat_id).map(|c| c.value().clone())
  }

  pub async fn summarize_database_row(
    &self,
    model_name: &str,
    data: SummaryRowContent,
  ) -> FlowyResult<String> {
    let client = self
      .client
      .read()
      .await
      .clone()
      .ok_or(FlowyError::local_ai())?
      .upgrade()
      .ok_or(FlowyError::local_ai())?;

    let chain = DatabaseSummaryChain::new(LLMOllama::new(model_name, client, None, None));
    let response = chain.summarize(data).await?;
    Ok(response)
  }

  pub async fn translate_database_row(
    &self,
    model_name: &str,
    cells: TranslateRowContent,
    language: &str,
  ) -> FlowyResult<TranslateRowResponse> {
    let client = self
      .client
      .read()
      .await
      .clone()
      .ok_or(FlowyError::local_ai())?
      .upgrade()
      .ok_or(FlowyError::local_ai())?;

    let chain = DatabaseTranslateChain::new(LLMOllama::new(model_name, client, None, None));
    let data = TranslateRowData {
      cells,
      language: language.to_string(),
      include_header: false,
    };
    let resp = chain.translate(data).await?;
    Ok(resp)
  }

  pub async fn complete_text(
    &self,
    model_name: &str,
    params: CompleteTextParams,
  ) -> Result<StreamComplete, FlowyError> {
    let client = self
      .client
      .read()
      .await
      .clone()
      .ok_or(FlowyError::local_ai())?
      .upgrade()
      .ok_or(FlowyError::local_ai())?;

    let chain = CompletionChain::new(LLMOllama::new(model_name, client, None, None));
    let ty = params.completion_type.unwrap_or(CompletionType::AskAI);
    let stream = chain
      .complete(&params.text, ty, params.format, params.metadata)
      .await?
      .boxed();
    Ok(stream)
  }

  pub async fn copy_file(
    &self,
    chat_id: &Uuid,
    message_id: i64,
    source_path: PathBuf,
  ) -> FlowyResult<String> {
    let chat = self
      .chat_by_id
      .get(chat_id)
      .map(|v| v.value().clone())
      .ok_or_else(|| FlowyError::internal().with_context("Chat not found"))?;
    chat.read().await.copy_file(message_id, source_path).await
  }

  #[instrument(skip_all, err)]
  pub async fn generate_embed_file_metadata(
    &self,
    chat_id: &Uuid,
    file_path: PathBuf,
  ) -> FlowyResult<serde_json::Value> {
    if !file_path.exists() {
      return Err(
        FlowyError::record_not_found().with_context("File path does not exist when embedding file"),
      );
    }

    let chat = self
      .chat_by_id
      .get(chat_id)
      .map(|v| v.value().clone())
      .ok_or_else(|| FlowyError::internal().with_context("Chat not found"))?;

    let metadata = chat.read().await.metadata_from_path(file_path.clone())?;
    Ok(metadata)
  }

  #[instrument(skip_all, err)]
  pub async fn embed_file(&self, chat_id: &Uuid, file_path: PathBuf) -> FlowyResult<()> {
    if !file_path.exists() {
      return Err(
        FlowyError::record_not_found().with_context("File path does not exist when embedding file"),
      );
    }

    info!(
      "[Chat] {} Embedding file from path: {}",
      chat_id,
      file_path.display()
    );

    let chat = self
      .chat_by_id
      .get(chat_id)
      .map(|v| v.value().clone())
      .ok_or_else(|| FlowyError::internal().with_context("Chat not found"))?;
    chat.read().await.embed_file_from_path(file_path).await?;
    Ok(())
  }

  pub async fn get_related_question(
    &self,
    _model_name: &str,
    chat_id: &Uuid,
    message_id: i64,
  ) -> FlowyResult<Vec<String>> {
    match self.get_chat(chat_id) {
      None => {
        warn!(
          "[Chat] Chat with id {} not found, unable to get related question",
          chat_id
        );
        Ok(vec![])
      },
      Some(chat) => {
        let user_service = self.user_service.upgrade().ok_or(FlowyError::local_ai())?;
        let uid = user_service.user_id()?;
        let mut conn = user_service.sqlite_connection(uid)?;
        match select_message_pair(&mut conn, &chat_id.to_string(), message_id)? {
          None => Ok(vec![]),
          Some((q, a)) => {
            chat
              .read()
              .await
              .get_related_question(&q.content, &a.content)
              .await
          },
        }
      },
    }
  }

  pub async fn ask_question(&self, chat_id: &Uuid, question: &str) -> FlowyResult<String> {
    if let Some(chat) = self.get_chat(chat_id) {
      let response = chat.read().await.ask_question(question).await;
      return response;
    }

    Err(FlowyError::local_ai().with_context(format!("Chat with id {} not found", chat_id)))
  }

  pub async fn stream_question(
    &self,
    chat_id: &Uuid,
    question: &str,
    format: ResponseFormat,
    model_name: &str,
    options: StreamQuestionOptions,
  ) -> FlowyResult<StreamAnswer> {
    if let Some(chat) = self.get_chat(chat_id) {
      chat.write().await.set_chat_model(model_name);
      let response = chat
        .write()
        .await
        .stream_question(question, format, options)
        .await;
      return response;
    }

    Err(FlowyError::local_ai().with_context(format!("Chat with id {} not found", chat_id)))
  }
}
