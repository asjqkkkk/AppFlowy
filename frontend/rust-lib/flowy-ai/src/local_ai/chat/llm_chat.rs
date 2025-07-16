use crate::SqliteVectorStore;
use crate::ai_tool::pdf::IMAGE_LLM_MODEL;
use crate::chat_file::ChatLocalFileStorage;
use crate::local_ai::chat::LLMChatInfo;
use crate::local_ai::chat::chains::conversation_chain::{
  ConversationalRetrieverChain, ConversationalRetrieverChainBuilder,
};
use crate::local_ai::chat::format_prompt::AFContextPrompt;
use crate::local_ai::chat::llm::LocalLLMController;
use crate::local_ai::chat::retriever::multi_source_retriever::MultipleSourceRetriever;
use crate::local_ai::chat::retriever::{
  AFEmbedder, AFRetriever, EmbedFileProgress, RetrieverStore,
};
use crate::local_ai::chat::summary_memory::SummaryMemory;
use async_trait::async_trait;
use flowy_ai_pub::cloud::{QuestionStreamValue, ResponseFormat, StreamAnswer};
use flowy_ai_pub::entities::{EmbeddingDimension, RAG_IDS, SOURCE_ID, WORKSPACE_ID};
use flowy_ai_pub::persistence::{ChatLocalFileTable, upsert_chat_local_file};
use flowy_ai_pub::user_service::AIUserService;
use flowy_error::{FlowyError, FlowyResult};
use flowy_sqlite::DBConnection;
use futures::Stream;
use futures::StreamExt;
use langchain_rust::chain::{Chain, ChainError};
use langchain_rust::memory::SimpleMemory;
use langchain_rust::prompt_args;
use langchain_rust::schemas::{Document, Message};
use langchain_rust::vectorstore::{VecStoreOptions, VectorStore};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::pin::Pin;
use std::sync::{Arc, Weak};
use tracing::{debug, error, instrument, trace};
use uuid::Uuid;

pub type RetrieverOption = VecStoreOptions<Value>;

pub struct LLMChat {
  store: Option<SqliteVectorStore>,
  chain: ConversationalRetrieverChain,
  prompt: AFContextPrompt,
  info: LLMChatInfo,
  local_file_storage: Option<Arc<ChatLocalFileStorage>>,
}

impl LLMChat {
  pub fn new(
    info: LLMChatInfo,
    llm_controller: LocalLLMController,
    store: Option<SqliteVectorStore>,
    user_service: Option<Weak<dyn AIUserService>>,
    retriever_sources: Vec<Weak<dyn RetrieverStore>>,
    local_file_storage: Option<Arc<ChatLocalFileStorage>>,
  ) -> FlowyResult<Self> {
    let response_format = ResponseFormat::default();
    let formatter = create_formatter_prompt_with_format(&response_format, &info.rag_ids);

    let memory = SummaryMemory::new(
      &info.chat_id,
      llm_controller.build_llm(None, None),
      info.summary.clone(),
      user_service.clone(),
    )
    .map(|v| v.into())
    .unwrap_or(SimpleMemory::new().into());

    let retriever = create_retriever(
      info.workspace_id,
      info.chat_id,
      info.rag_ids.clone(),
      store.clone(),
      retriever_sources,
      user_service.clone(),
    );
    let embedder = Arc::new(AFEmbedderImpl {
      workspace_id: info.workspace_id,
      chat_id: info.chat_id,
      store: store.clone(),
      file_storage: local_file_storage.clone(),
      user_service,
    });

    let builder = ConversationalRetrieverChainBuilder::new(
      info.workspace_id,
      llm_controller.clone(),
      retriever,
      embedder,
      store.clone(),
    )
    .rephrase_question(true)
    .memory(memory);

    let chain = builder.prompt(formatter.clone()).build()?;
    Ok(Self {
      store,
      chain,
      prompt: formatter,
      info,
      local_file_storage,
    })
  }

  pub async fn copy_file(&self, message_id: i64, source_path: PathBuf) -> FlowyResult<String> {
    let file_storage = self.local_file_storage.as_ref().ok_or_else(|| {
      FlowyError::new(
        flowy_error::ErrorCode::InvalidParams,
        "File storage is not initialized",
      )
    })?;

    let copied_path = file_storage
      .copy_file(&self.info.chat_id, message_id, source_path)
      .await?;

    copied_path.to_str().map(|s| s.to_string()).ok_or_else(|| {
      FlowyError::new(
        flowy_error::ErrorCode::InvalidParams,
        "Invalid file path encoding",
      )
    })
  }

  pub async fn get_message_files(&self, message_id: i64) -> Vec<String> {
    match &self.local_file_storage {
      Some(file_storage) => file_storage
        .get_files_for_chat(&self.info.chat_id.to_string(), Some(message_id))
        .await
        .unwrap_or_default(),
      None => Vec::new(),
    }
  }

  pub async fn get_related_question(
    &self,
    question: &str,
    answer: &str,
  ) -> FlowyResult<Vec<String>> {
    self.chain.get_related_questions(question, answer).await
  }

  pub fn set_chat_model(&mut self, model: &str) {
    self.chain.set_model_name(model.to_string())
  }

  pub fn set_rag_ids(&mut self, rag_ids: Vec<String>) {
    self.prompt.set_rag_ids(&rag_ids);
    self.chain.retriever.set_rag_ids(rag_ids);
  }

  #[instrument(skip_all, err)]
  pub async fn embed_file_from_path(&self, file_path: PathBuf) -> FlowyResult<()> {
    let mut stream = self.chain.embedder.embed_file(&file_path).await?;

    // Consume the stream to completion
    while let Some(result) = stream.next().await {
      result?; // Propagate any errors
    }

    Ok(())
  }

  #[instrument(skip_all, err)]
  pub fn metadata_from_path(&self, file_path: PathBuf) -> FlowyResult<serde_json::Value> {
    let store = self
      .store
      .as_ref()
      .ok_or_else(|| FlowyError::local_ai().with_context("VectorStore is not initialized"))?;

    store.metadata_from_path(file_path)
  }

  pub async fn search(
    &self,
    query: &str,
    limit: usize,
    ids: Vec<String>,
  ) -> FlowyResult<Vec<Document>> {
    let store = self
      .store
      .as_ref()
      .ok_or_else(|| FlowyError::local_ai().with_context("VectorStore is not initialized"))?;

    let options = RetrieverOption::new()
      .with_filters(json!({RAG_IDS: ids, "workspace_id": self.info.workspace_id}));
    let result = store
      .similarity_search(query, limit, &options)
      .await
      .map_err(|err| FlowyError::local_ai().with_context(err))?;
    Ok(result)
  }

  #[cfg(any(target_os = "windows", target_os = "macos", target_os = "linux"))]
  pub async fn get_all_embedded_documents(
    &self,
    dim: EmbeddingDimension,
  ) -> FlowyResult<Vec<flowy_sqlite_vec::entities::SqliteEmbeddedDocument>> {
    let store = self
      .store
      .as_ref()
      .ok_or_else(|| FlowyError::local_ai().with_context("VectorStore is not initialized"))?;

    store
      .select_all_embedded_documents(&self.info.workspace_id.to_string(), &self.info.rag_ids, dim)
      .await
      .map_err(|err| {
        FlowyError::local_ai().with_context(format!("Failed to select embedded documents: {}", err))
      })
  }

  pub async fn embed_paragraphs(
    &self,
    object_id: &str,
    paragraphs: Vec<String>,
  ) -> FlowyResult<()> {
    let metadata = HashMap::from([
      (WORKSPACE_ID.to_string(), json!(self.info.workspace_id)),
      (SOURCE_ID.to_string(), json!(object_id)),
    ]);

    let document = Document::new(paragraphs.join("\n\n")).with_metadata(metadata);
    if let Some(store) = &self.store {
      store
        .add_documents(&[document], &VecStoreOptions::default())
        .await
        .map_err(|err| FlowyError::local_ai().with_context(err))?;
    }
    Ok(())
  }

  pub async fn ask_question(&self, question: &str) -> FlowyResult<String> {
    let input_variables = prompt_args! {
        "question" => question,
    };

    let result = self
      .chain
      .invoke(input_variables)
      .await
      .map_err(map_chain_error)?;
    Ok(result)
  }

  /// Send a message to the chat and get a response
  pub async fn stream_question(
    &mut self,
    message: &str,
    format: ResponseFormat,
    options: StreamQuestionOptions,
  ) -> Result<StreamAnswer, FlowyError> {
    debug!(
      "[chat]: {} stream question: {}, options: {:?}",
      self.info.chat_id, message, options
    );
    self.prompt.set_format(&format)?;
    let chat_history = self.chain.get_chat_history(0).await?;
    let input_variables = prompt_args! {
        "question" => message,
        "files" => options.files,
        "chat_history" => chat_history,
    };

    let stream_result = self.chain.stream(input_variables).await;
    let stream = stream_result.map_err(map_chain_error)?;
    let transformed_stream = stream.map(|result| {
      result
        .map(|stream_data| {
          serde_json::from_value::<QuestionStreamValue>(stream_data.value).unwrap_or_else(|_| {
            QuestionStreamValue::Answer {
              value: String::new(),
            }
          })
        })
        .map_err(map_chain_error)
    });
    Ok(Box::pin(transformed_stream))
  }
}

#[derive(Default, Debug, Clone, Serialize, Deserialize)]
pub struct StreamQuestionOptions {
  files: Vec<EmbedFile>,
}

impl StreamQuestionOptions {
  pub fn new() -> Self {
    Self::default()
  }

  pub fn new_with_files(files: Vec<EmbedFile>) -> Self {
    Self { files }
  }
  pub fn with_file(mut self, file: EmbedFile) -> Self {
    self.files.push(file);
    self
  }

  pub fn try_with_path(mut self, path: String) -> FlowyResult<Self> {
    let file = EmbedFile::try_from_path(path)?;
    self.files.push(file);
    Ok(self)
  }
}

#[derive(Default, Debug, Clone, Serialize, Deserialize)]
pub struct EmbedFile {
  pub name: String,
  pub path: String,
}

impl EmbedFile {
  pub fn try_from_path(path: String) -> FlowyResult<Self> {
    let name = Path::new(path.as_str())
      .file_name()
      .and_then(|s| s.to_str())
      .ok_or_else(|| FlowyError::local_ai().with_context("Invalid file name"))?
      .to_string();
    Ok(Self { path, name })
  }
}

fn create_formatter_prompt_with_format(
  format: &ResponseFormat,
  rag_ids: &[String],
) -> AFContextPrompt {
  let system_message =
    Message::new_system_message("You are an assistant for question-answering tasks");
  AFContextPrompt::new(system_message, format, rag_ids)
}

fn create_retriever(
  workspace_id: Uuid,
  chat_id: Uuid,
  rag_ids: Vec<String>,
  store: Option<SqliteVectorStore>,
  retrievers_sources: Vec<Weak<dyn RetrieverStore>>,
  user_service: Option<Weak<dyn AIUserService>>,
) -> Box<dyn AFRetriever> {
  trace!(
    "[VectorStore]: {} create retriever with rag_ids: {:?}",
    workspace_id, rag_ids,
  );

  let mut stores: Vec<Arc<dyn RetrieverStore>> = vec![];
  if let Some(store) = store {
    stores.push(Arc::new(store));
  }

  for source in retrievers_sources {
    if let Some(source) = source.upgrade() {
      stores.push(source);
    }
  }

  trace!(
    "[VectorStore]: use retrievers sources: {:?}",
    stores
      .iter()
      .map(|s| s.retriever_name())
      .collect::<Vec<_>>()
  );

  Box::new(MultipleSourceRetriever::new(
    workspace_id,
    chat_id,
    stores,
    rag_ids.clone(),
    user_service,
  ))
}

fn map_chain_error(err: ChainError) -> FlowyError {
  match err {
    ChainError::MissingInputVariable(var) => {
      FlowyError::local_ai().with_context(format!("Missing input variable: {}", var))
    },
    ChainError::MissingObject(obj) => {
      FlowyError::local_ai().with_context(format!("Missing object: {}", obj))
    },
    ChainError::RetrieverError(err) => {
      FlowyError::local_ai().with_context(format!("Retriever error: {}", err))
    },
    _ => FlowyError::local_ai().with_context(format!("Chain error: {:?}", err)),
  }
}

struct AFEmbedderImpl {
  workspace_id: Uuid,
  chat_id: Uuid,
  store: Option<SqliteVectorStore>,
  file_storage: Option<Arc<ChatLocalFileStorage>>,
  user_service: Option<Weak<dyn AIUserService>>,
}

impl AFEmbedderImpl {
  fn user_service(&self) -> FlowyResult<Arc<dyn AIUserService>> {
    self
      .user_service
      .as_ref()
      .and_then(|v| v.upgrade())
      .ok_or_else(|| FlowyError::ref_drop().with_context("User service is not available"))
  }

  fn sqlite_connection(&self) -> FlowyResult<DBConnection> {
    let user_service = self.user_service()?;
    let uid = user_service.user_id()?;
    user_service.sqlite_connection(uid)
  }
}

#[async_trait]
impl AFEmbedder for AFEmbedderImpl {
  async fn embed_file(
    &self,
    file_path: &Path,
  ) -> FlowyResult<Pin<Box<dyn Stream<Item = FlowyResult<EmbedFileProgress>> + Send>>> {
    let Some(store) = &self.store else {
      return Err(FlowyError::internal().with_context(format!(
        "VectorStore is not initialized, cannot embed file: {:?}",
        file_path
      )));
    };

    let workspace_id = self.workspace_id;
    let chat_id = self.chat_id;
    let file_path_owned = file_path.to_path_buf();

    let store_clone = store.clone();
    let file_storage = self.file_storage.clone();
    let db_connection = self.sqlite_connection().ok();
    let chat_id_str = self.chat_id.to_string();
    let file_path_str = file_path.to_string_lossy().to_string();

    let stream = async_stream::stream! {
      // Call the store's embed_file_from_path_stream method
      match store_clone
        .embed_file_from_path_stream(
          &workspace_id,
          &chat_id,
          &file_path_owned,
          IMAGE_LLM_MODEL,
        )
        .await
      {
        Ok(mut progress_stream) => {
          let mut final_content = String::new();

          // Forward all progress events from the store
          while let Some(progress_result) = progress_stream.next().await {
            match progress_result {
              Ok(progress) => {
                // Capture the final content if this is the completion event
                if let EmbedFileProgress::Completed { ref content } = progress {
                  final_content = content.clone();
                }
                yield Ok(progress);
              }
              Err(e) => {
                yield Err(e);
                // Continue to allow cleanup even on error
              }
            }
          }

          // Save to database if we have content
          if !final_content.is_empty() {
            if let Some(db) = db_connection {
              let record = ChatLocalFileTable::new_with_uuid(
                chat_id_str.clone(),
                file_path_str.clone(),
                final_content.clone(),
              );

              if let Err(err) = upsert_chat_local_file(db, &record) {
                error!(
                  "Failed to upsert chat local file: {:?}, error: {}",
                  file_path_owned, err
                );
              }
            }
          }
        }
        Err(embed_err) => {
          // Emit error event
          yield Ok(EmbedFileProgress::Error {
            message: embed_err.to_string()
          });

          // Attempt to delete the file if embedding failed
          if let Some(file_storage) = &file_storage {
            if let Err(delete_err) = file_storage.delete_file(&file_path_str).await {
              error!(
                "Failed to delete file {:?} after embedding error: {}. Original error: {}",
                file_path_owned, delete_err, embed_err
              );
            }
          }

          yield Err(embed_err);
        }
      }
    };

    Ok(Box::pin(stream))
  }
}
