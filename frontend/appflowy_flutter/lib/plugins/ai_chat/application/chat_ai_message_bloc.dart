import 'package:appflowy/plugins/ai_chat/application/chat_entity.dart';
import 'package:appflowy/plugins/ai_chat/application/chat_message_stream.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-ai/entities.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'chat_message_service.dart';

part 'chat_ai_message_bloc.freezed.dart';

class ChatAIMessageBloc extends Bloc<ChatAIMessageEvent, ChatAIMessageState> {
  ChatAIMessageBloc({
    dynamic message,
    String? refSourceJsonString,
    required this.chatId,
    required this.questionId,
  }) : super(
          ChatAIMessageState.initial(
            message,
            parseMetadata(refSourceJsonString),
          ),
        ) {
    _registerEventHandlers();
    _initializeStreamListener();
    _checkInitialStreamState();
  }

  final String chatId;
  final Int64? questionId;

  void _registerEventHandlers() {
    // Handle text updates and ready state
    on<_UpdateText>((event, emit) {
      emit(
        state.copyWith(
          text: event.text,
          status: ChatMessageStatus.ready,
          error: null,
        ),
      );
    });

    // Handle all status changes
    on<_UpdateStatus>((event, emit) {
      emit(
        state.copyWith(
          status: event.status,
          error: event.error,
          sources: event.sources ?? state.sources,
          followUpData: event.followUpData ?? state.followUpData,
          recentProgressSteps: event.progress != null
              ? _updateRecentProgress(
                  state.recentProgressSteps,
                  event.progress!,
                )
              : state.recentProgressSteps,
        ),
      );
    });

    // Handle metadata updates
    on<_UpdateMetadata>((event, emit) {
      emit(
        state.copyWith(
          sources: event.metadata.sources,
          recentProgressSteps: event.metadata.progress != null
              ? _updateRecentProgress(
                  state.recentProgressSteps,
                  event.metadata.progress!,
                )
              : state.recentProgressSteps,
        ),
      );
    });

    // Handle retry
    on<_Retry>((event, emit) async {
      if (questionId == null) {
        Log.error("Question id is not valid: $questionId");
        return;
      }

      emit(
        state.copyWith(
          status: ChatMessageStatus.loading,
        ),
      );

      final payload = ChatMessageIdPB(
        chatId: chatId,
        messageId: questionId,
      );

      final result = await AIEventGetAnswerForQuestion(payload).send();
      if (!isClosed) {
        result.fold(
          (answer) => add(ChatAIMessageEvent.updateText(answer.content)),
          (err) => add(
            ChatAIMessageEvent.updateStatus(
              ChatMessageStatus.error,
              error: err.toString(),
            ),
          ),
        );
      }
    });
  }

  void _initializeStreamListener() {
    if (state.stream != null) {
      state.stream!.listen(
        onData: (text) => _safeAdd(ChatAIMessageEvent.updateText(text)),
        onError: (error) => _safeAdd(
          ChatAIMessageEvent.updateStatus(
            ChatMessageStatus.error,
            error: error.toString(),
          ),
        ),
        onAIResponseLimit: () => _safeAdd(
          const ChatAIMessageEvent.updateStatus(
            ChatMessageStatus.aiResponseLimit,
          ),
        ),
        onAIImageResponseLimit: () => _safeAdd(
          const ChatAIMessageEvent.updateStatus(
            ChatMessageStatus.aiImageResponseLimit,
          ),
        ),
        onMetadata: (metadata) => _safeAdd(
          ChatAIMessageEvent.updateMetadata(metadata),
        ),
        onAIMaxRequired: (message) => _safeAdd(
          ChatAIMessageEvent.updateStatus(
            ChatMessageStatus.aiMaxRequired,
            error: message,
          ),
        ),
        onLocalAIInitializing: () => _safeAdd(
          const ChatAIMessageEvent.updateStatus(
            ChatMessageStatus.initializingLocalAI,
          ),
        ),
        onAIFollowUp: (data) => _safeAdd(
          ChatAIMessageEvent.updateStatus(
            ChatMessageStatus.aiFollowUp,
            followUpData: data,
          ),
        ),
        onProgress: (step) => _safeAdd(
          ChatAIMessageEvent.updateStatus(
            ChatMessageStatus.processing,
            progress: AIChatProgress(step: step),
          ),
        ),
      );
    }
  }

  void _checkInitialStreamState() {
    if (state.stream != null) {
      if (state.stream!.aiLimitReached) {
        add(
          const ChatAIMessageEvent.updateStatus(
            ChatMessageStatus.aiResponseLimit,
          ),
        );
      } else if (state.stream!.error != null) {
        add(
          ChatAIMessageEvent.updateStatus(
            ChatMessageStatus.error,
            error: state.stream!.error!,
          ),
        );
      }
    }
  }

  void _safeAdd(ChatAIMessageEvent event) {
    if (!isClosed) {
      add(event);
    }
  }

  /// Helper method to maintain a list of recent AIChatProgress values (max 5)
  List<AIChatProgress> _updateRecentProgress(
    List<AIChatProgress> currentProgresses,
    AIChatProgress newProgress,
  ) {
    final updatedProgresses = [newProgress, ...currentProgresses];
    if (updatedProgresses.length > 5) {
      return updatedProgresses.take(5).toList();
    }
    return updatedProgresses;
  }
}

@freezed
class ChatAIMessageEvent with _$ChatAIMessageEvent {
  const factory ChatAIMessageEvent.updateText(String text) = _UpdateText;
  const factory ChatAIMessageEvent.updateStatus(
    ChatMessageStatus status, {
    String? error,
    List<ChatMessageRefSource>? sources,
    AIChatProgress? progress,
    AIFollowUpData? followUpData,
  }) = _UpdateStatus;
  const factory ChatAIMessageEvent.updateMetadata(
    MetadataCollection metadata,
  ) = _UpdateMetadata;
  const factory ChatAIMessageEvent.retry() = _Retry;
}

@freezed
class ChatAIMessageState with _$ChatAIMessageState {
  const factory ChatAIMessageState({
    AnswerStream? stream,
    required String text,
    required ChatMessageStatus status,
    String? error,
    required List<ChatMessageRefSource> sources,
    AIFollowUpData? followUpData,
    required List<AIChatProgress> recentProgressSteps,
  }) = _ChatAIMessageState;

  factory ChatAIMessageState.initial(
    dynamic text,
    MetadataCollection metadata,
  ) {
    return ChatAIMessageState(
      text: text is String ? text : "",
      stream: text is AnswerStream ? text : null,
      status: ChatMessageStatus.ready,
      sources: metadata.sources,
      recentProgressSteps:
          metadata.progress != null ? [metadata.progress!] : [],
    );
  }
}

// Simplified status enum that covers all cases
enum ChatMessageStatus {
  ready,
  loading,
  processing,
  error,
  aiResponseLimit,
  aiImageResponseLimit,
  aiMaxRequired,
  initializingLocalAI,
  aiFollowUp,
}

// Extension to help with status checks
extension ChatMessageStatusX on ChatMessageStatus {
  bool get isError => this == ChatMessageStatus.error;
  bool get isLoading =>
      this == ChatMessageStatus.loading || this == ChatMessageStatus.processing;
  bool get isReady => this == ChatMessageStatus.ready;
  bool get hasLimitReached =>
      this == ChatMessageStatus.aiResponseLimit ||
      this == ChatMessageStatus.aiImageResponseLimit ||
      this == ChatMessageStatus.aiMaxRequired;
}
