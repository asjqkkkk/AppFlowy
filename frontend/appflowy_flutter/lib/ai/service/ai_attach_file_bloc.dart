import 'dart:async';

import 'package:appflowy/plugins/ai_chat/application/chat_entity.dart';
import 'package:appflowy/plugins/ai_chat/application/chat_message_listener.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/protobuf/flowy-ai/entities.pbserver.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_attach_file_bloc.freezed.dart';

class AIAattachFileBloc extends Bloc<AIAattachFileEvent, AIAattachFileState> {
  AIAattachFileBloc({
    required this.chatId,
  })  : listener = ChatMessageListener(chatId: chatId),
        super(AIAattachFileState.initial()) {
    on<AIAattachFileEvent>(
      (event, emit) {
        event.when(
          didLoadFiles: (files) {
            emit(state.copyWith(files: files));
          },
          refresh: () {
            _loadAttachedFiles();
          },
          failedToEmbedFile: (error) {
            emit(state.copyWith(embedFileError: error));
          },
        );
      },
    );

    _loadAttachedFiles();
    listener.start(
      didUploadChatFileCallback: () {
        _loadAttachedFiles();
      },
      failedToEmbedFile: (data) {
        if (isClosed) {
          return;
        }
        add(AIAattachFileEvent.failedToEmbedFile(data));
      },
    );
  }

  final String chatId;
  final ChatMessageListener listener;

  Future<void> _loadAttachedFiles() async {
    final payload = ChatId.create()..value = chatId;
    unawaited(
      AIEventGetAttachedChatFiles(payload).send().then(
        (result) {
          result.fold(
            (data) {
              if (isClosed) {
                return;
              }
              final files = data.files
                  .map((file) => ChatFile.fromFilePath(file))
                  .where((e) => e != null)
                  .cast<ChatFile>()
                  .toList();
              add(AIAattachFileEvent.didLoadFiles(files));
            },
            (error) {},
          );
        },
      ),
    );
  }

  @override
  Future<void> close() async {
    await listener.stop();
    return super.close();
  }
}

@freezed
class AIAattachFileEvent with _$AIAattachFileEvent {
  const factory AIAattachFileEvent.didLoadFiles(
    List<ChatFile> files,
  ) = _DidLoadFiles;

  const factory AIAattachFileEvent.refresh() = _Refresh;

  const factory AIAattachFileEvent.failedToEmbedFile(
    EmbedFileErrorPB error,
  ) = _FailedToEmbedFile;
}

@freezed
class AIAattachFileState with _$AIAattachFileState {
  const factory AIAattachFileState({
    required List<ChatFile> files,
    EmbedFileErrorPB? embedFileError,
  }) = _AIAattachFileState;

  factory AIAattachFileState.initial() {
    return AIAattachFileState(
      files: [],
    );
  }
}
