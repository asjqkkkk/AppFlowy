import 'dart:async';

import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-ai/entities.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:bloc/bloc.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'ollama_setting_bloc.freezed.dart';

const kDefaultEmbeddingModel = 'nomic-embed-text:latest';

/// Extension methods to map between PB and UI models
class OllamaSettingBloc extends Bloc<OllamaSettingEvent, OllamaSettingState> {
  OllamaSettingBloc() : super(const OllamaSettingState()) {
    on<_Started>(_handleStarted);
    on<_DidLoadLocalModels>(_onLoadLocalModels);
    on<_DidLoadSetting>(_onLoadSetting);
    on<_UpdateSetting>(_onLoadSetting);
    on<_OnEdit>(_onEdit);
    on<_OnSubmit>(_onSubmit);
    on<_SetDefaultModel>(_onSetDefaultModel);
    on<_SetSelectedEmbeddingModel>(_onSetSelectedEmbeddingModel);
    on<_DidLoadEmbeddingModels>(_didLoadEmbeddingModels);
    on<_NotifyResult>(_onNotifyResult);
  }

  Future<void> _handleStarted(
    _Started event,
    Emitter<OllamaSettingState> emit,
  ) async {
    try {
      final results = await Future.wait([
        AIEventGetLocalModelSelection().send().then((r) => r.getOrThrow()),
        AIEventGetLocalAISetting().send().then((r) => r.getOrThrow()),
        AIEventGetLocalEmbeddingModelSelection()
            .send()
            .then((r) => r.getOrThrow()),
      ]);

      final models = results[0] as ModelSelectionPB;
      final setting = results[1] as LocalAISettingPB;
      final embeddingModels = results[2] as EmbeddingModelSelectionPB;

      if (!isClosed) {
        add(OllamaSettingEvent.didLoadLocalModels(models));
        add(OllamaSettingEvent.didLoadSetting(setting));
        add(OllamaSettingEvent.didLoadEmbeddingModels(embeddingModels));
      }
    } catch (e, st) {
      Log.error('Failed to load initial AI data: $e\n$st');
    }
  }

  void _onLoadLocalModels(
    _DidLoadLocalModels event,
    Emitter<OllamaSettingState> emit,
  ) {
    emit(state.copyWith(localModels: event.models));
  }

  void _onLoadSetting(
    dynamic event,
    Emitter<OllamaSettingState> emit,
  ) {
    final setting = (event as dynamic).setting as LocalAISettingPB;
    final submitted = setting.toSubmittedItems();
    emit(
      state.copyWith(
        successOrFail: null,
        setting: setting,
        inputItems: setting.toInputItems(),
        submittedItems: submitted,
        originalMap: {
          for (final item in submitted) item.settingType: item.content,
        },
        isEdited: false,
      ),
    );
  }

  void _onEdit(
    _OnEdit event,
    Emitter<OllamaSettingState> emit,
  ) {
    final updated = state.submittedItems
        .map(
          (item) => item.settingType == event.settingType
              ? item.copyWith(content: event.content)
              : item,
        )
        .toList();

    final currentMap = {for (final i in updated) i.settingType: i.content};
    final isEdited = !const MapEquality<SettingType, String>()
        .equals(state.originalMap, currentMap);

    emit(
      state.copyWith(
        submittedItems: updated,
        isEdited: isEdited,
        successOrFail: null,
      ),
    );
  }

  void _onSubmit(
    _OnSubmit event,
    Emitter<OllamaSettingState> emit,
  ) {
    final pb = LocalAISettingPB();
    for (final item in state.submittedItems) {
      switch (item.settingType) {
        case SettingType.serverUrl:
          pb.serverUrl = item.content;
          break;
        case SettingType.chatModel:
          pb.globalChatModel = state.selectedModel?.name ?? item.content;
          break;
        case SettingType.embeddingModel:
          pb.embeddingModelName = state.selectedEmbeddingModel ?? item.content;
          break;
      }
    }
    add(OllamaSettingEvent.updateSetting(pb));
    AIEventUpdateLocalAISetting(pb).send().then((result) {
      if (isClosed) return;
      add(OllamaSettingEvent.notifyResult(result));
    });
  }

  void _onSetDefaultModel(
    _SetDefaultModel event,
    Emitter<OllamaSettingState> emit,
  ) {
    emit(
      state.copyWith(
        selectedModel: event.model,
        isEdited: true,
        successOrFail: null,
      ),
    );
  }

  void _didLoadEmbeddingModels(
    _DidLoadEmbeddingModels event,
    Emitter<OllamaSettingState> emit,
  ) {
    emit(state.copyWith(embeddingModels: event.models));
  }

  void _onSetSelectedEmbeddingModel(
    _SetSelectedEmbeddingModel event,
    Emitter<OllamaSettingState> emit,
  ) {
    emit(
      state.copyWith(
        selectedEmbeddingModel: event.embeddingModel,
        isEdited: true,
        successOrFail: null,
      ),
    );
  }

  void _onNotifyResult(
    _NotifyResult event,
    Emitter<OllamaSettingState> emit,
  ) {
    emit(state.copyWith(successOrFail: event.successOrFail));
  }
}

/// Setting types for mapping
enum SettingType {
  serverUrl,
  chatModel,
  embeddingModel;

  String get title {
    switch (this) {
      case SettingType.serverUrl:
        return 'Ollama server url';
      case SettingType.chatModel:
        return 'Default model name';
      case SettingType.embeddingModel:
        return 'Embedding model name';
    }
  }
}

/// Input field representation
class SettingItem extends Equatable {
  const SettingItem({
    required this.content,
    required this.hintText,
    required this.settingType,
    this.editable = true,
  });

  final String content;
  final String hintText;
  final SettingType settingType;
  final bool editable;

  @override
  List<Object?> get props => [content, settingType, editable];
}

/// Items pending submission
class SubmittedItem extends Equatable {
  const SubmittedItem({
    required this.content,
    required this.settingType,
  });

  final String content;
  final SettingType settingType;

  /// Returns a copy of this SubmittedItem with given fields updated.
  SubmittedItem copyWith({
    String? content,
    SettingType? settingType,
  }) {
    return SubmittedItem(
      content: content ?? this.content,
      settingType: settingType ?? this.settingType,
    );
  }

  @override
  List<Object?> get props => [content, settingType];
}

@freezed
class OllamaSettingEvent with _$OllamaSettingEvent {
  const factory OllamaSettingEvent.started() = _Started;
  const factory OllamaSettingEvent.didLoadLocalModels(
    ModelSelectionPB models,
  ) = _DidLoadLocalModels;
  const factory OllamaSettingEvent.didLoadSetting(
    LocalAISettingPB setting,
  ) = _DidLoadSetting;
  const factory OllamaSettingEvent.updateSetting(
    LocalAISettingPB setting,
  ) = _UpdateSetting;
  const factory OllamaSettingEvent.setDefaultModel(
    AIModelPB model,
  ) = _SetDefaultModel;
  const factory OllamaSettingEvent.onEdit(
    String content,
    SettingType settingType,
  ) = _OnEdit;
  const factory OllamaSettingEvent.submit() = _OnSubmit;

  const factory OllamaSettingEvent.didLoadEmbeddingModels(
    EmbeddingModelSelectionPB models,
  ) = _DidLoadEmbeddingModels;
  const factory OllamaSettingEvent.setSelectedEmbeddingModel(
    String embeddingModel,
  ) = _SetSelectedEmbeddingModel;

  const factory OllamaSettingEvent.notifyResult(
    FlowyResult<void, FlowyError>? successOrFail,
  ) = _NotifyResult;
}

@freezed
class OllamaSettingState with _$OllamaSettingState {
  const factory OllamaSettingState({
    LocalAISettingPB? setting,
    @Default([]) List<SettingItem> inputItems,
    AIModelPB? selectedModel,
    String? selectedEmbeddingModel,
    ModelSelectionPB? localModels,
    EmbeddingModelSelectionPB? embeddingModels,
    AIModelPB? defaultModel,
    @Default([]) List<SubmittedItem> submittedItems,
    @Default(false) bool isEdited,
    @Default({}) Map<SettingType, String> originalMap,
    FlowyResult<void, FlowyError>? successOrFail,
  }) = _OllamaSettingState;
}

extension on LocalAISettingPB {
  List<SettingItem> toInputItems() => [
        SettingItem(
          content: serverUrl,
          hintText: 'http://localhost:11434',
          settingType: SettingType.serverUrl,
        ),
      ];

  List<SubmittedItem> toSubmittedItems() => [
        SubmittedItem(
          content: serverUrl,
          settingType: SettingType.serverUrl,
        ),
        SubmittedItem(
          content: globalChatModel,
          settingType: SettingType.chatModel,
        ),
        SubmittedItem(
          content: embeddingModelName,
          settingType: SettingType.embeddingModel,
        ),
      ];
}
