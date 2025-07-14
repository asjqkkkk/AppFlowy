use flowy_derive::ProtoBuf_Enum;
use flowy_notification::NotificationBuilder;
use num_enum::{IntoPrimitive, TryFromPrimitive};
use tracing::trace;

const CHAT_OBSERVABLE_SOURCE: &str = "Chat";
pub const APPFLOWY_AI_NOTIFICATION_KEY: &str = "appflowy_ai_plugin";
#[derive(ProtoBuf_Enum, Debug, Default, IntoPrimitive, TryFromPrimitive, Clone)]
#[repr(i32)]
pub enum ChatNotification {
  #[default]
  Unknown = 0,
  DidLoadLatestChatMessage = 1,
  DidLoadPrevChatMessage = 2,
  DidReceiveChatMessage = 3,
  StreamChatMessageError = 4,
  FinishStreaming = 5,
  UpdateLocalAIState = 6,
  DidUpdateChatSettings = 7,
  LocalAIResourceUpdated = 8,
  DidUpdateSelectedModel = 9,
  DidAddNewChatFile = 10,
  FailedToEmbedFile = 11,
}

#[tracing::instrument(level = "trace", skip_all)]
pub(crate) fn chat_notification_builder<T: ToString>(
  id: T,
  ty: ChatNotification,
) -> NotificationBuilder {
  let id = id.to_string();
  trace!("chat_notification_builder: id = {id}, ty = {ty:?}");
  NotificationBuilder::new(&id, ty, CHAT_OBSERVABLE_SOURCE)
}
