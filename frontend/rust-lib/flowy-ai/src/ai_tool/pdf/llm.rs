use base64::{Engine as _, engine::general_purpose};
use flowy_error::{FlowyError, FlowyResult};
use ollama_rs::{
  Ollama,
  generation::{completion::request::GenerationRequest, images::Image},
  models::ModelOptions,
};

/// Configuration for AI-based image analysis
#[derive(Debug, Clone)]
pub struct ImageAnalysisConfig {
  pub model: String,
  pub custom_prompt: Option<String>,
}

impl ImageAnalysisConfig {
  /// Creates a new configuration with the specified model
  pub fn new(model: String) -> Self {
    Self {
      model,
      custom_prompt: None,
    }
  }
}

const DEFAULT_IMAGE_PROMPT: &str =
  "extract text from image. Remove duplicated text and format it nicely";

pub async fn extract_text_from_image(
  ollama: &Ollama,
  image_bytes: Vec<u8>,
  config: &ImageAnalysisConfig,
) -> FlowyResult<String> {
  let prompt = config
    .custom_prompt
    .as_ref()
    .unwrap_or(&DEFAULT_IMAGE_PROMPT.to_string())
    .clone();

  let image = tokio::task::spawn_blocking(move || {
    let base64_image = general_purpose::STANDARD.encode(image_bytes);
    Image::from_base64(&base64_image)
  })
  .await?;

  // Create generation request
  let request = GenerationRequest::new(config.model.clone(), prompt)
    .images(vec![image])
    .options(ModelOptions::default());

  // Send request to Ollama
  ollama
    .generate(request)
    .await
    .map(|response| response.response.trim().to_owned())
    .map_err(|e| FlowyError::internal().with_context(format!("Failed to analyze image: {}", e)))
}
