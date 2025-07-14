#![allow(dead_code)]

use flowy_ai::local_ai::chat::llm::LLMOllama;
use langchain_rust::language_models::llm::LLM;
use langchain_rust::schemas::Message;
use ollama_rs::generation::parameters::{FormatType, JsonStructure};
use schemars::JsonSchema;
use serde::Deserialize;

/// Similarity checking response structure
#[derive(Debug, Deserialize, JsonSchema)]
struct SimilarityResponse {
  is_similar: bool,
  confidence: f32,
  explanation: String,
}

/// Check if two texts are semantically similar using LLM
pub async fn assert_content_similar(
  actual: &str,
  expected: &str,
  context: Option<&str>,
  threshold: f32,
) -> anyhow::Result<()> {
  let format = FormatType::StructuredJson(JsonStructure::new::<SimilarityResponse>());
  let llm = LLMOllama::default().with_format(format);

  let context_str = context.unwrap_or("");
  let prompt = format!(
    r#"Analyze if these two texts are semantically similar.
Context: {}

Text 1 (Actual):
{}

Text 2 (Expected):
{}

Respond with a JSON object containing:
- is_similar: boolean indicating if the texts convey the same meaning
- confidence: float between 0-1 indicating confidence level
- explanation: brief explanation of similarity/difference"#,
    context_str, actual, expected
  );

  let messages = vec![
    Message::new_system_message(
      "You are a precise text similarity analyzer. Focus on semantic meaning rather than exact wording.",
    ),
    Message::new_human_message(&prompt),
  ];

  let result = llm.generate(&messages).await?;
  let similarity: SimilarityResponse = serde_json::from_str(&result.generation)?;

  if similarity.confidence >= threshold && similarity.is_similar {
    println!(
      "Content similarity assertion passed:\n\
             Expected (similar to): {}\n\
             Actual: {}\n\
             Confidence: {:.2}\n\
             Explanation: {}",
      expected, actual, similarity.confidence, similarity.explanation
    );
    Ok(())
  } else {
    anyhow::bail!(
      "Content similarity assertion failed:\n\
             Expected (similar to): {}\n\
             Actual: {}\n\
             Confidence: {:.2}\n\
             Explanation: {}",
      expected,
      actual,
      similarity.confidence,
      similarity.explanation
    )
  }
}

#[derive(Debug, Deserialize, JsonSchema)]
struct ConceptCheck {
  concept: String,
  is_present: bool,
  evidence: Option<String>,
}

/// Helper to validate that a response is about a specific topic
pub async fn assert_response_about_topic(
  response: &str,
  expected_topic: &str,
) -> anyhow::Result<()> {
  let format = FormatType::StructuredJson(JsonStructure::new::<TopicCheckResponse>());
  let llm = LLMOllama::default().with_format(format);
  let prompt = format!(
    r#"Is this response primarily about the topic: "{}"?

Response:
{}

Analyze if the response is focused on the given topic."#,
    expected_topic, response
  );

  let messages = vec![
    Message::new_system_message("You are analyzing if a text response is about a specific topic."),
    Message::new_human_message(&prompt),
  ];

  let result = llm.generate(&messages).await?;
  let topic_check: TopicCheckResponse = serde_json::from_str(&result.generation)?;
  if topic_check.is_about_topic && topic_check.confidence >= 0.7 {
    Ok(())
  } else {
    anyhow::bail!(
      "Response is not about expected topic '{}'\n\
             Response: {}\n\
             Confidence: {:.2}\n\
             Explanation: {}",
      expected_topic,
      response,
      topic_check.confidence,
      topic_check.explanation
    )
  }
}

#[derive(Debug, Deserialize, JsonSchema)]
struct TopicCheckResponse {
  is_about_topic: bool,
  confidence: f32,
  explanation: String,
}
