use async_trait::async_trait;
use futures::Stream;
use langchain_rust::language_models::llm::LLM;
use langchain_rust::language_models::{GenerateResult, LLMError, TokenUsage};
use langchain_rust::schemas::{Message, StreamData};
use ollama_rs::error::OllamaError;
use std::ops::{Deref, DerefMut};
use std::pin::Pin;
use std::sync::Arc;
use tokio_stream::StreamExt;

use crate::embeddings::indexer::LocalEmbeddingModel;
use crate::local_ai::controller::LocalAISetting;
use flowy_ai_pub::entities::EmbeddingDimension;
use flowy_error::FlowyResult;
use ollama_rs::Ollama;
use ollama_rs::generation::chat::request::ChatMessageRequest;
use ollama_rs::generation::embeddings::GenerateEmbeddingsResponse;
use ollama_rs::generation::embeddings::request::GenerateEmbeddingsRequest;
use ollama_rs::generation::parameters::FormatType;
use ollama_rs::models::{LocalModel, ModelInfo, ModelOptions};
use tracing::debug;

#[derive(Debug, Clone)]
pub struct AFLLM {
  ollama: Arc<Ollama>,
  format: Option<FormatType>,
  options: Option<ModelOptions>,
  pub model_name: String,
}

impl Default for AFLLM {
  fn default() -> Self {
    AFLLM {
      model_name: "gemma3:4b".to_string(),
      ollama: Arc::new(Ollama::default()),
      format: None,
      options: None,
    }
  }
}

impl AFLLM {
  pub fn new(
    model: &str,
    ollama: Arc<Ollama>,
    format: Option<FormatType>,
    options: Option<ModelOptions>,
  ) -> Self {
    AFLLM {
      model_name: model.to_string(),
      ollama,
      format,
      options,
    }
  }

  pub fn with_options(mut self, options: ModelOptions) -> Self {
    self.options = Some(options);
    self
  }

  pub fn set_format(&mut self, format: FormatType) {
    debug!("set format {:?}", format);
    self.format = Some(format);
  }

  pub fn set_model(&mut self, model: &str) {
    debug!("set model {}", model);
    self.model_name = model.to_string();
  }

  /// Get model information from Ollama API using the built-in method
  pub async fn get_model_info(&self) -> Result<ModelInfo, LLMError> {
    debug!("get model:{} info", self.model_name);
    self
      .ollama
      .show_model_info(self.model_name.clone())
      .await
      .map_err(LLMError::from)
  }

  pub fn estimate_token_count(&self, text: &str) -> usize {
    // Simple heuristic: ~4 characters per token for English text
    // This is model-dependent, but provides a reasonable approximation
    (text.len() as f32 / 4.0).ceil() as usize
  }

  /// Calculate how many messages can fit in the context window
  pub async fn calculate_message_capacity(
    &self,
    messages: &[Message],
    reserved_tokens: usize, // Reserve tokens for system prompt, response, etc.
  ) -> Result<usize, LLMError> {
    let model_info = self.get_model_info().await?;
    // Extract context length from ModelInfo - it's in the model_info map
    let context_length = model_info
      .model_info
      .get("context_length")
      .and_then(|v| v.as_u64())
      .map(|v| v as usize)
      .unwrap_or(4096); // Default to 4k if not found

    // Reserve space for system messages, response, and safety margin
    let available_tokens = context_length.saturating_sub(reserved_tokens);
    let mut total_tokens = 0;
    let mut message_count = 0;

    debug!(
      "[Tokens]: Available tokens before processing messages: {}",
      available_tokens
    );
    // Start from the most recent messages and work backwards
    for message in messages.iter().rev() {
      let message_tokens = self.estimate_token_count(&message.content) + 10; // +10 for role/metadata
      if total_tokens + message_tokens > available_tokens {
        break;
      }
      total_tokens += message_tokens;
      message_count += 1;
    }

    Ok(message_count)
  }

  fn generate_request(&self, messages: &[Message]) -> ChatMessageRequest {
    let mapped_messages = messages.iter().map(|message| message.into()).collect();
    let mut request = ChatMessageRequest::new(self.model_name.clone(), mapped_messages);
    if let Some(option) = &self.options {
      request = request.options(option.clone())
    }
    if let Some(format) = &self.format {
      request = request.format(format.clone());
    }
    request
  }
}

impl Deref for AFLLM {
  type Target = Arc<Ollama>;

  fn deref(&self) -> &Self::Target {
    &self.ollama
  }
}

impl DerefMut for AFLLM {
  fn deref_mut(&mut self) -> &mut Self::Target {
    &mut self.ollama
  }
}

#[async_trait]
impl LLM for AFLLM {
  async fn generate(&self, messages: &[Message]) -> Result<GenerateResult, LLMError> {
    let request = self.generate_request(messages);
    let result = self.ollama.send_chat_messages(request).await?;
    let generation = result.message.content;
    let tokens = result.final_data.map(|final_data| {
      let prompt_tokens = final_data.prompt_eval_count as u32;
      let completion_tokens = final_data.eval_count as u32;
      TokenUsage {
        prompt_tokens,
        completion_tokens,
        total_tokens: prompt_tokens + completion_tokens,
      }
    });

    Ok(GenerateResult { tokens, generation })
  }

  async fn stream(
    &self,
    messages: &[Message],
  ) -> Result<Pin<Box<dyn Stream<Item = Result<StreamData, LLMError>> + Send>>, LLMError> {
    let request = self.generate_request(messages);
    let result = self.ollama.send_chat_messages_stream(request).await?;

    let stream = result.map(|data| match data {
      Ok(data) => Ok(StreamData::new(
        serde_json::to_value(&data).unwrap_or_default(),
        None,
        data.message.content,
      )),
      Err(_) => Err(OllamaError::Other("Stream error".to_string()).into()),
    });

    Ok(Box::pin(stream))
  }
}

#[derive(Debug, Clone)]
pub struct LocalLLMController {
  ollama: Arc<Ollama>,
  model_name: String,
  embed_model: LocalEmbeddingModel,
}

impl LocalLLMController {
  pub fn new(ollama: Arc<Ollama>, model_name: String, embed_model: LocalEmbeddingModel) -> Self {
    LocalLLMController {
      ollama,
      model_name,
      embed_model,
    }
  }

  pub fn is_setting_changed(&self, setting: &LocalAISetting) -> bool {
    if self.ollama.uri() != setting.ollama_server_url {
      debug!(
        "Ollama server URL changed from {} to {}",
        self.ollama.uri(),
        setting.ollama_server_url
      );
      return true;
    }

    if self.model_name != setting.chat_model_name {
      debug!(
        "LLM model changed from {} to {}",
        self.model_name, setting.chat_model_name
      );
      return true;
    }

    if self.embed_model.name() != setting.embedding_model_name {
      debug!(
        "Embedding model changed from {} to {}",
        self.embed_model.name(),
        setting.embedding_model_name
      );
      return true;
    }

    false
  }

  pub fn build_llm(&self, format: Option<FormatType>, options: Option<ModelOptions>) -> AFLLM {
    let model_name = self.model_name.clone();
    AFLLM::new(&model_name, self.ollama.clone(), format, options)
  }

  pub fn build_with_model(&self, model: &str) -> AFLLM {
    AFLLM::new(model, self.ollama.clone(), None, None)
  }

  pub fn global_model(&self) -> String {
    self.model_name.clone()
  }

  pub fn uri(&self) -> String {
    self.ollama.uri()
  }

  pub fn url_str(&self) -> &str {
    self.ollama.url_str()
  }

  pub async fn show_model_info(&self, model_name: String) -> FlowyResult<ModelInfo> {
    let info = self.ollama.show_model_info(model_name).await?;
    Ok(info)
  }

  pub async fn list_local_models(&self) -> FlowyResult<Vec<LocalModel>> {
    let models = self.ollama.list_local_models().await?;
    Ok(models)
  }

  pub async fn generate_embeddings(
    &self,
    request: GenerateEmbeddingsRequest,
  ) -> FlowyResult<GenerateEmbeddingsResponse> {
    let resp = self.ollama.generate_embeddings(request).await?;
    Ok(resp)
  }

  pub fn set_embed_model(&mut self, embed_model: LocalEmbeddingModel) {
    debug!("set embed model {}", embed_model);
    self.embed_model = embed_model;
  }

  pub fn get_embed_model(&self) -> &LocalEmbeddingModel {
    &self.embed_model
  }

  pub fn embed_model(&self) -> LocalEmbeddingModel {
    self.embed_model.clone()
  }

  pub fn embed_dimension(&self) -> EmbeddingDimension {
    self.embed_model.dimension()
  }

  pub async fn embed(
    &self,
    request: GenerateEmbeddingsRequest,
  ) -> FlowyResult<GenerateEmbeddingsResponse> {
    let resp = self.ollama.generate_embeddings(request).await?;
    Ok(resp)
  }
}
