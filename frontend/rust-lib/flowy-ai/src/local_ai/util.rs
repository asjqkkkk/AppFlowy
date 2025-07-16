use ollama_rs::models::ModelInfo;

pub fn is_model_support_vision(model_info: &ModelInfo) -> bool {
  model_info
    .model_info
    .keys()
    .any(|key| key.contains(".vision."))
}
