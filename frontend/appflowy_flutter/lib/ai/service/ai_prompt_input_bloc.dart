import 'dart:async';

import 'package:appflowy/ai/service/ai_model_state_notifier.dart';
import 'package:appflowy/plugins/ai_chat/application/chat_entity.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'ai_entities.dart';

part 'ai_prompt_input_bloc.freezed.dart';

class AIPromptInputBloc extends Bloc<AIPromptInputEvent, AIPromptInputState> {
  AIPromptInputBloc({
    required this.objectId,
    required PredefinedFormat? predefinedFormat,
  })  : aiModelStateNotifier = AIModelStateNotifier(objectId: objectId),
        super(AIPromptInputState.initial(predefinedFormat)) {
    _dispatch();
    _startListening();
    _init();
  }

  final AIModelStateNotifier aiModelStateNotifier;
  final String objectId;

  String? promptId;

  @override
  Future<void> close() async {
    aiModelStateNotifier.dispose();
    return super.close();
  }

  void _dispatch() {
    on<AIPromptInputEvent>(
      (event, emit) {
        event.when(
          updateAIState: (modelState) {
            emit(
              state.copyWith(
                modelState: modelState,
              ),
            );
          },
          toggleShowPredefinedFormat: () {
            final showPredefinedFormats = !state.showPredefinedFormats;
            final predefinedFormat =
                showPredefinedFormats && state.predefinedFormat == null
                    ? PredefinedFormat(
                        imageFormat: ImageFormat.text,
                        textFormat: TextFormat.paragraph,
                      )
                    : null;
            emit(
              state.copyWith(
                showPredefinedFormats: showPredefinedFormats,
                predefinedFormat: predefinedFormat,
              ),
            );
          },
          updatePredefinedFormat: (format) {
            if (!state.showPredefinedFormats) {
              return;
            }
            emit(state.copyWith(predefinedFormat: format));
          },
          attachFile: (filePath, fileName) {
            final newFile = ChatFile.fromFilePath(filePath);
            if (newFile != null) {
              emit(
                state.copyWith(
                  attachedFiles: [...state.attachedFiles, newFile],
                ),
              );
            }
          },
          removeFile: (file) {
            final files = [...state.attachedFiles];
            files.remove(file);
            emit(
              state.copyWith(
                attachedFiles: files,
              ),
            );
          },
          updateMentionedViews: (views) {
            emit(
              state.copyWith(
                mentionedPages: views,
              ),
            );
          },
          updatePromptId: (promptId) {
            this.promptId = promptId;
          },
          clearMetadata: () {
            promptId = null;
            emit(
              state.copyWith(
                attachedFiles: [],
                mentionedPages: [],
              ),
            );
          },
          receivedEmptyModelList: () {
            emit(state.copyWith(isEmptyList: true));
            emit(state.copyWith(isEmptyList: false));
          },
        );
      },
    );
  }

  void _startListening() {
    aiModelStateNotifier.addListener(() {
      add(
        AIPromptInputEvent.updateAIState(aiModelStateNotifier.state),
      );
    });
  }

  void _init() {
    final modelState = aiModelStateNotifier.state;
    add(AIPromptInputEvent.updateAIState(modelState));

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!isClosed &&
          aiModelStateNotifier.modelSelection.availableModels.isEmpty) {
        add(const AIPromptInputEvent.receivedEmptyModelList());
      }
    });
  }

  Map<String, ViewPB> consumeAttachedMentions() {
    final metadata = {
      for (final page in state.mentionedPages) page.id: page,
    };

    return metadata;
  }

  Map<String, ChatFile> consumeAttachedFiles() {
    final metadata = {
      for (final file in state.attachedFiles) file.filePath: file,
    };

    return metadata;
  }

  void clearMetadata() {
    if (!isClosed) {
      add(const AIPromptInputEvent.clearMetadata());
    }
  }
}

@freezed
class AIPromptInputEvent with _$AIPromptInputEvent {
  const factory AIPromptInputEvent.updateAIState(
    AIModelState modelState,
  ) = _UpdateAIState;

  const factory AIPromptInputEvent.toggleShowPredefinedFormat() =
      _ToggleShowPredefinedFormat;
  const factory AIPromptInputEvent.updatePredefinedFormat(
    PredefinedFormat format,
  ) = _UpdatePredefinedFormat;
  const factory AIPromptInputEvent.attachFile(
    String filePath,
    String fileName,
  ) = _AttachFile;
  const factory AIPromptInputEvent.removeFile(ChatFile file) = _RemoveFile;
  const factory AIPromptInputEvent.updateMentionedViews(List<ViewPB> views) =
      _UpdateMentionedViews;
  const factory AIPromptInputEvent.clearMetadata() = _ClearMetadata;
  const factory AIPromptInputEvent.updatePromptId(String promptId) =
      _UpdatePromptId;
  const factory AIPromptInputEvent.receivedEmptyModelList() =
      _ReceivedEmptyModelList;
}

@freezed
class AIPromptInputState with _$AIPromptInputState {
  const factory AIPromptInputState({
    required AIModelState modelState,
    required bool showPredefinedFormats,
    required PredefinedFormat? predefinedFormat,
    required List<ChatFile> attachedFiles,
    required List<ViewPB> mentionedPages,
    required bool isEmptyList,
  }) = _AIPromptInputState;

  factory AIPromptInputState.initial(PredefinedFormat? format) =>
      AIPromptInputState(
        modelState: AIModelState(
          type: AiType.cloud,
          isEditable: true,
          hintText: '',
          localAIEnabled: false,
          supportChatWithFile: false,
        ),
        showPredefinedFormats: format != null,
        predefinedFormat: format,
        attachedFiles: [],
        mentionedPages: [],
        isEmptyList: false,
      );
}
