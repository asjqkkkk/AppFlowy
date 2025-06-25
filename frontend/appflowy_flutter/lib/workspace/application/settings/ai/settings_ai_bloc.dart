import 'package:appflowy/plugins/ai_chat/application/ai_model_switch_listener.dart';
import 'package:appflowy/user/application/user_listener.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-ai/entities.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'local_llm_listener.dart';

const String aiModelsGlobalActiveModel = "global_active_model";

class SettingsAIBloc extends Bloc<SettingsAIEvent, SettingsAIState> {
  SettingsAIBloc(
    UserProfilePB userProfile,
    this.workspaceId,
  )   : _userListener = UserListener(userProfile: userProfile),
        _aiModelSwitchListener =
            AIModelSwitchListener(objectId: aiModelsGlobalActiveModel),
        super(SettingsAIState()) {
    on<SettingsAIStarted>(_onStarted);
    on<SettingsAIToggleAISearch>(_onToggleAISearch);
    on<SettingsAISelectModel>(_onSelectModel);
    on<SettingsAIDidLoadWorkspaceSetting>(_onDidLoadWorkspaceSetting);
    on<SettingsAIDidLoadAvailableModels>(_onDidLoadAvailableModels);
    on<SettingsAIDidUpdateLocalAIState>(_onDidUpdateLocalAIState);
  }

  final UserListener _userListener;
  final String workspaceId;
  final AIModelSwitchListener _aiModelSwitchListener;
  final _localAIStateListener = LocalAIStateListener();

  @override
  Future<void> close() async {
    await _userListener.stop();
    await _aiModelSwitchListener.stop();
    await _localAIStateListener.stop();
    return super.close();
  }

  Future<void> _onStarted(
    SettingsAIStarted event,
    Emitter<SettingsAIState> emit,
  ) async {
    _userListener.start(
      onUserWorkspaceSettingUpdated: (settings) {
        if (!isClosed) {
          add(SettingsAIEvent.didLoadWorkspaceSetting(settings));
        }
      },
    );
    _aiModelSwitchListener.start(
      onUpdateSelectedModel: (model) {
        if (!isClosed) {
          _loadModelList();
        }
      },
    );
    _localAIStateListener.start(
      stateCallback: (pluginState) {
        if (!isClosed) {
          add(SettingsAIEvent.didReceiveAiState(pluginState));
        }
      },
    );
    _loadModelList();
    _loadUserWorkspaceSetting();
  }

  void _onToggleAISearch(
    SettingsAIToggleAISearch event,
    Emitter<SettingsAIState> emit,
  ) {
    emit(
      state.copyWith(enableSearchIndexing: !state.enableSearchIndexing),
    );
    _updateUserWorkspaceSetting(
      disableSearchIndexing:
          !(state.aiSettings?.disableSearchIndexing ?? false),
    );
  }

  Future<void> _onSelectModel(
    SettingsAISelectModel event,
    Emitter<SettingsAIState> emit,
  ) async {
    await AIEventUpdateSelectedModel(
      UpdateSelectedModelPB(
        source: aiModelsGlobalActiveModel,
        selectedModel: event.model,
      ),
    ).send();
  }

  void _onDidLoadWorkspaceSetting(
    SettingsAIDidLoadWorkspaceSetting event,
    Emitter<SettingsAIState> emit,
  ) {
    emit(
      state.copyWith(
        aiSettings: event.settings,
        enableSearchIndexing: !event.settings.disableSearchIndexing,
      ),
    );
  }

  void _onDidLoadAvailableModels(
    SettingsAIDidLoadAvailableModels event,
    Emitter<SettingsAIState> emit,
  ) {
    emit(
      state.copyWith(
        availableModels: event.models,
      ),
    );
  }

  void _onDidUpdateLocalAIState(
    SettingsAIDidUpdateLocalAIState event,
    Emitter<SettingsAIState> emit,
  ) {
    emit(
      state.copyWith(
        isLocalAIEnabled: event.pluginState.enabled,
      ),
    );
  }

  Future<FlowyResult<void, FlowyError>> _updateUserWorkspaceSetting({
    bool? disableSearchIndexing,
    String? model,
  }) async {
    final payload = UpdateUserWorkspaceSettingPB(
      workspaceId: workspaceId,
    );
    if (disableSearchIndexing != null) {
      payload.disableSearchIndexing = disableSearchIndexing;
    }
    if (model != null) {
      payload.aiModel = model;
    }
    final result = await UserEventUpdateWorkspaceSetting(payload).send();
    result.fold(
      (ok) => Log.info('Update workspace setting success'),
      (err) => Log.error('Update workspace setting failed: $err'),
    );
    return result;
  }

  void _loadModelList() {
    final payload = ModelSourcePB(source: aiModelsGlobalActiveModel);
    AIEventGetSettingModelSelection(payload).send().then((result) {
      result.fold((models) {
        if (!isClosed) {
          add(SettingsAIEvent.didLoadAvailableModels(models));
        }
      }, (err) {
        Log.error(err);
      });
    });
  }

  void _loadUserWorkspaceSetting() {
    final payload = UserWorkspaceIdPB(workspaceId: workspaceId);
    UserEventGetWorkspaceSetting(payload).send().then((result) {
      result.fold((settings) {
        if (!isClosed) {
          add(SettingsAIEvent.didLoadWorkspaceSetting(settings));
        }
      }, (err) {
        Log.error(err);
      });
    });
  }
}

sealed class SettingsAIEvent {
  const SettingsAIEvent();

  const factory SettingsAIEvent.started() = SettingsAIStarted;
  const factory SettingsAIEvent.didLoadWorkspaceSetting(
    WorkspaceSettingsPB settings,
  ) = SettingsAIDidLoadWorkspaceSetting;
  const factory SettingsAIEvent.toggleAISearch() = SettingsAIToggleAISearch;
  const factory SettingsAIEvent.selectModel(AIModelPB model) =
      SettingsAISelectModel;
  const factory SettingsAIEvent.didLoadAvailableModels(
    ModelSelectionPB models,
  ) = SettingsAIDidLoadAvailableModels;
  const factory SettingsAIEvent.didReceiveAiState(LocalAIPB pluginState) =
      SettingsAIDidUpdateLocalAIState;
}

class SettingsAIStarted extends SettingsAIEvent {
  const SettingsAIStarted();
}

class SettingsAIDidLoadWorkspaceSetting extends SettingsAIEvent {
  const SettingsAIDidLoadWorkspaceSetting(this.settings);

  final WorkspaceSettingsPB settings;
}

class SettingsAIToggleAISearch extends SettingsAIEvent {
  const SettingsAIToggleAISearch();
}

class SettingsAISelectModel extends SettingsAIEvent {
  const SettingsAISelectModel(this.model);

  final AIModelPB model;
}

class SettingsAIDidLoadAvailableModels extends SettingsAIEvent {
  const SettingsAIDidLoadAvailableModels(this.models);

  final ModelSelectionPB models;
}

class SettingsAIDidUpdateLocalAIState extends SettingsAIEvent {
  const SettingsAIDidUpdateLocalAIState(this.pluginState);

  final LocalAIPB pluginState;
}

class SettingsAIState extends Equatable {
  const SettingsAIState({
    this.aiSettings,
    this.availableModels,
    this.enableSearchIndexing = true,
    this.isLocalAIEnabled = true,
  });

  final WorkspaceSettingsPB? aiSettings;
  final ModelSelectionPB? availableModels;
  final bool enableSearchIndexing;
  final bool isLocalAIEnabled;

  SettingsAIState copyWith({
    WorkspaceSettingsPB? aiSettings,
    ModelSelectionPB? availableModels,
    bool? isLocalAIEnabled,
    bool? enableSearchIndexing,
  }) {
    return SettingsAIState(
      aiSettings: aiSettings ?? this.aiSettings,
      availableModels: availableModels ?? this.availableModels,
      enableSearchIndexing: enableSearchIndexing ?? this.enableSearchIndexing,
      isLocalAIEnabled: isLocalAIEnabled ?? this.isLocalAIEnabled,
    );
  }

  @override
  List<Object?> get props => [
        aiSettings,
        availableModels,
        enableSearchIndexing,
        isLocalAIEnabled,
      ];
}
