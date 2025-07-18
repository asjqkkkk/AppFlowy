use ollama_rs::Ollama;
use ollama_rs::models::ModelInfo;
use tracing::debug;

pub fn is_model_support_vision(model_info: &ModelInfo) -> bool {
  model_info
    .model_info
    .keys()
    .any(|key| key.contains(".vision."))
}

pub fn is_support_embedding(
  supported_dimensions: &[usize],
  model_name: &str,
  model_info: &ModelInfo,
) -> bool {
  if let Some(dimension) = dimension_from_model_info(model_name, model_info) {
    return supported_dimensions.contains(&dimension);
  }
  false
}

pub fn dimension_from_model_info(model_name: &str, model_info: &ModelInfo) -> Option<usize> {
  model_info.model_info.iter().find_map(|(key, value)| {
    if key.contains("embedding_length") {
      debug!("embedding_length: {} for model:{}", value, model_name);
      value.as_i64().map(|v| v as usize)
    } else {
      None
    }
  })
}

pub async fn get_embedding_model_dimension(ollama: &Ollama, model_name: &str) -> Option<usize> {
  let model_info = ollama.show_model_info(model_name.to_string()).await.ok()?;
  dimension_from_model_info(model_name, &model_info)
}
