use crate::setup_log;
use client_api::entity::chat_dto::CompletionStreamValue;
use client_api::entity::{CompletionType, OutputLayout, ResponseFormat};
use flowy_ai::local_ai::chat::llm::AFLLM;
use flowy_ai::local_ai::completion::chain::CompletionChain;
use flowy_error::FlowyError;
use futures_util::StreamExt;
use tokio_stream::wrappers::ReceiverStream;
use tracing::error;

#[tokio::test]
async fn local_ai_test_simple_ask_ai() {
  let ollama = AFLLM::default();
  let ai_completion = CompletionChain::new(ollama);
  let text = "Compare js with Rust";
  let ty = CompletionType::AskAI;
  let mut format = ResponseFormat::new();
  format.output_layout = OutputLayout::SimpleTable;

  let stream = ai_completion
    .complete(text, ty, format, None)
    .await
    .unwrap();
  let (answer, comment) = collect_completion_stream(stream).await;
  dbg!(&answer);
  assert!(!answer.is_empty());
  assert!(comment.is_empty());
}

#[tokio::test]
async fn local_ai_test_improve_writing() {
  setup_log();
  let ollama = AFLLM::default();
  let ai_completion = CompletionChain::new(ollama);
  let text = "I like playing basketball with my friend";
  let ty = CompletionType::ImproveWriting;
  let format = ResponseFormat::default();
  let stream = ai_completion
    .complete(text, ty, format, None)
    .await
    .unwrap();
  let (answer, comment) = collect_completion_stream(stream).await;
  dbg!(&answer);
  dbg!(&comment);
  assert!(!answer.is_empty());
  assert!(!comment.is_empty());
}

#[tokio::test]
async fn local_ai_test_simple_fix_grammar() {
  setup_log();
  let ollama = AFLLM::default();
  let ai_completion = CompletionChain::new(ollama);
  let text = "He starts work everyday at 8 a.m";
  let ty = CompletionType::SpellingAndGrammar;
  let format = ResponseFormat::default();
  let stream = ai_completion
    .complete(text, ty, format, None)
    .await
    .unwrap();
  let (answer, comment) = collect_completion_stream(stream).await;
  dbg!(&answer);
  dbg!(&comment);
  assert!(!answer.is_empty());
  assert!(!comment.is_empty());
}

async fn collect_completion_stream(
  mut stream: ReceiverStream<Result<CompletionStreamValue, FlowyError>>,
) -> (String, String) {
  let mut answer = Vec::new();
  let mut comment = Vec::new();
  while let Some(item) = stream.next().await {
    match item {
      Ok(CompletionStreamValue::Answer { value }) => {
        dbg!(&value);
        answer.push(value);
      },
      Ok(CompletionStreamValue::Comment { value }) => {
        dbg!(&value);
        comment.push(value);
      },
      Err(e) => {
        error!("[collect_completion_stream] error: {:?}", e);
      },
    }
  }
  (answer.join(""), comment.join(""))
}
