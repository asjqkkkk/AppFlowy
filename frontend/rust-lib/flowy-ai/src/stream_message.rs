use serde::Serialize;
use std::fmt::Display;

#[allow(dead_code)]
pub enum StreamMessage {
  MessageId(i64),
  OnData(String),
  OnFollowUp(AIFollowUpData),
  OnError(String),
  Metadata(String),
  Done,
  OnProcess(String),
  AIResponseLimitExceeded,
  AIImageResponseLimitExceeded,
  AIMaxRequired(String),
  LocalAINotReady(String),
  LocalAIDisabled(String),
}

#[derive(Debug, Clone, Serialize, Default)]
pub struct AIFollowUpData {
  pub should_generate_related_question: bool,
}

impl Display for StreamMessage {
  fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
    match self {
      StreamMessage::MessageId(message_id) => write!(f, "message_id:{}", message_id),
      StreamMessage::OnData(message) => write!(f, "data:{message}"),
      StreamMessage::OnError(message) => write!(f, "error:{message}"),
      StreamMessage::Done => write!(f, "done:"),
      StreamMessage::Metadata(s) => write!(f, "metadata:{s}"),
      StreamMessage::OnFollowUp(data) => {
        if let Ok(s) = serde_json::to_string(&data) {
          write!(f, "ai_follow_up:{}", s)
        } else {
          write!(f, "ai_follow_up:",)
        }
      },
      StreamMessage::OnProcess(message) => write!(f, "progress:{message}"),
      StreamMessage::AIResponseLimitExceeded => write!(f, "ai_response_limit:"),
      StreamMessage::AIImageResponseLimitExceeded => write!(f, "ai_image_response_limit:"),
      StreamMessage::AIMaxRequired(message) => write!(f, "ai_max_required:{}", message),
      StreamMessage::LocalAINotReady(message) => write!(f, "local_ai_not_ready:{}", message),
      StreamMessage::LocalAIDisabled(message) => write!(f, "local_ai_disabled:{}", message),
    }
  }
}
