import 'package:appflowy/ai/ai.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/ai_chat/application/ai_model_switch_listener.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/workspace/application/settings/ai/local_llm_listener.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-ai/entities.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_platform/universal_platform.dart';

/// Repository pattern for AI data operations
class AIModelRepository {
  Future<FlowyResult<ModelSelectionPB, FlowyError>> fetchModelSelection(
    String objectId,
  ) async {
    return AIEventGetSourceModelSelection(
      ModelSourcePB(source: objectId),
    ).send();
  }

  Future<FlowyResult<LocalAIStatePB, FlowyError>> fetchLocalAIState() async {
    return AIEventGetLocalAIState().send();
  }
}

/// Main refactored notifier with backward compatible API
class AIModelStateNotifier extends ChangeNotifier {
  AIModelStateNotifier({
    required this.objectId,
    AIPlatformConfig? platformConfig,
    AIModelRepository? repository,
  })  : _platformConfig = platformConfig ?? _createPlatformConfig(),
        _repository = repository ?? AIModelRepository(),
        _stateComputer = AIStateComputer(
          platformConfig ?? _createPlatformConfig(),
        ) {
    _initialize();
  }

  final String objectId;
  final AIPlatformConfig _platformConfig;
  final AIModelRepository _repository;
  final AIStateComputer _stateComputer;

  // Listeners
  LocalAIStateListener? _localAIListener;
  late final AIModelSwitchListener _aiModelSwitchListener;

  // State
  AIModelState _currentState = AIModelState.initial();
  ModelSelectionState _modelSelection = const ModelSelectionState(
    availableModels: [],
  );
  LocalAIStatePB? _localAIState;

  // Public getters
  AIModelState get state => _currentState;
  ModelSelectionState get modelSelection => _modelSelection;
  bool get hasError => _currentState.error != null;

  static AIPlatformConfig _createPlatformConfig() {
    return UniversalPlatform.isDesktop
        ? DesktopPlatformConfig()
        : MobilePlatformConfig();
  }

  void _initialize() {
    _setupListeners();
    _loadInitialData();
  }

  void _setupListeners() {
    // Setup AI model switch listener
    _aiModelSwitchListener = AIModelSwitchListener(objectId: objectId);
    _aiModelSwitchListener.start(
      onUpdateSelectedModel: _handleModelUpdate,
    );

    _localAIListener = LocalAIStateListener();
    _localAIListener!.start(
      stateCallback: _handleLocalAIStateUpdate,
    );
  }

  Future<void> _loadInitialData() async {
    try {
      await Future.wait([
        _loadModelSelection(),
        if (_platformConfig.supportsLocalAI) _loadLocalAIState(),
      ]);
      _updateState();
    } catch (e) {
      Log.error('Failed to load initial AI data: $e');
      _updateStateWithError(e.toString());
    }
  }

  Future<void> _loadModelSelection() async {
    final result = await _repository.fetchModelSelection(objectId);
    result.fold(
      (selection) {
        _modelSelection = ModelSelectionState(
          availableModels: selection.models,
          selectedModel: selection.selectedModel,
        );
      },
      (error) {
        Log.error('Failed to fetch model selection: $error');
        _updateStateWithError(error.toString());
      },
    );
  }

  Future<void> _loadLocalAIState() async {
    final result = await _repository.fetchLocalAIState();
    result.fold(
      (state) => _localAIState = state,
      (error) => Log.error('Failed to fetch local AI state: $error'),
    );
  }

  void _handleModelUpdate(AIModelPB model) async {
    _modelSelection = ModelSelectionState(
      availableModels: _modelSelection.availableModels,
      selectedModel: model,
    );

    // Reload local AI state if switching to local model
    if (model.isLocal && _platformConfig.supportsLocalAI) {
      await _loadLocalAIState();
    }

    _updateState();
  }

  void _handleLocalAIStateUpdate(LocalAIStatePB state) async {
    _localAIState = state;
    await _loadModelSelection();
    _updateState();
  }

  void _updateState() {
    final AIModelState newState = _stateComputer.computeState(
      modelSelection: _modelSelection,
      localAIState: _localAIState,
    );

    _currentState = newState;
    notifyListeners();
  }

  void _updateStateWithError(String error) {
    final newState = _currentState.copyWith(error: error);
    _currentState = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _localAIListener?.stop();
    _aiModelSwitchListener.stop();
    super.dispose();
  }
}

extension AIModelPBExtension on AIModelPB {
  bool get isDefault => name == 'Auto';
  String get i18n =>
      isDefault ? LocaleKeys.chat_switchModel_autoModel.tr() : name;
}

typedef OnModelStateChangedCallback = void Function(AIModelState state);
typedef OnAvailableModelsChangedCallback = void Function(
  List<AIModelPB>,
  AIModelPB?,
);

/// Represents the state of an AI model - now immutable and comparable
class AIModelState extends Equatable {
  const AIModelState({
    required this.type,
    required this.hintText,
    this.tooltip,
    required this.isEditable,
    required this.localAIEnabled,
    required this.supportChatWithFile,
    this.error,
  });

  factory AIModelState.initial() => AIModelState(
        type: AiType.cloud,
        hintText: LocaleKeys.chat_inputMessageHint.tr(),
        isEditable: true,
        localAIEnabled: false,
        supportChatWithFile: false,
      );

  final AiType type;
  final String hintText;
  final String? tooltip;
  final bool isEditable;
  final bool localAIEnabled;
  final bool supportChatWithFile;
  final String? error;

  @override
  List<Object?> get props => [
        type,
        hintText,
        tooltip,
        isEditable,
        localAIEnabled,
        supportChatWithFile,
        error,
      ];

  AIModelState copyWith({
    AiType? type,
    String? hintText,
    String? tooltip,
    bool? isEditable,
    bool? localAIEnabled,
    bool? supportChatWithFile,
    String? error,
  }) {
    return AIModelState(
      type: type ?? this.type,
      hintText: hintText ?? this.hintText,
      tooltip: tooltip ?? this.tooltip,
      isEditable: isEditable ?? this.isEditable,
      localAIEnabled: localAIEnabled ?? this.localAIEnabled,
      supportChatWithFile: supportChatWithFile ?? this.supportChatWithFile,
      error: error ?? this.error,
    );
  }
}

/// Model selection state - separate from the AI state
class ModelSelectionState extends Equatable {
  const ModelSelectionState({
    required this.availableModels,
    this.selectedModel,
  });

  final List<AIModelPB> availableModels;
  final AIModelPB? selectedModel;

  @override
  List<Object?> get props => [availableModels, selectedModel];
}

/// Platform-specific configuration abstraction
abstract class AIPlatformConfig {
  bool get supportsLocalAI;
  bool get isTestMode;
}

class DesktopPlatformConfig implements AIPlatformConfig {
  @override
  bool get supportsLocalAI => true;

  @override
  bool get isTestMode => FlowyRunner.currentMode.isTest;
}

class MobilePlatformConfig implements AIPlatformConfig {
  @override
  bool get supportsLocalAI => false;

  @override
  bool get isTestMode => false;
}

/// State computation logic extracted into a separate class
class AIStateComputer {
  const AIStateComputer(this.platformConfig);

  final AIPlatformConfig platformConfig;

  AIModelState computeState({
    required ModelSelectionState modelSelection,
    LocalAIStatePB? localAIState,
  }) {
    // Mobile or no model selected - return default state
    if (!platformConfig.supportsLocalAI ||
        modelSelection.selectedModel == null) {
      return AIModelState.initial();
    }

    // Test mode - return default state
    if (platformConfig.isTestMode) {
      return AIModelState.initial();
    }

    final selectedModel = modelSelection.selectedModel!;

    // Cloud model selected
    if (!selectedModel.isLocal) {
      return _computeCloudAIState(modelSelection);
    }

    // Local AI model selected
    if (localAIState == null) {
      return AIModelState.initial().copyWith(
        error: LocaleKeys.settings_aiPage_keys_localAIDisabled.tr(),
      );
    }

    return _computeLocalAIState(localAIState);
  }

  AIModelState _computeCloudAIState(ModelSelectionState modelSelection) {
    return AIModelState(
      type: AiType.cloud,
      hintText: LocaleKeys.chat_inputMessageHint.tr(),
      isEditable: true,
      localAIEnabled: false,
      supportChatWithFile: false,
    );
  }

  AIModelState _computeLocalAIState(LocalAIStatePB localAIState) {
    final enabled = localAIState.toggleOn;
    final running = localAIState.isReady;

    String hintText;
    String? tooltip;

    if (!enabled) {
      hintText = LocaleKeys.settings_aiPage_keys_localAIDisabled.tr();
      tooltip =
          LocaleKeys.settings_aiPage_keys_localAIDisabledTextFieldPrompt.tr();
    } else if (!running) {
      hintText = LocaleKeys.settings_aiPage_keys_localAIInitializing.tr();
      tooltip =
          LocaleKeys.settings_aiPage_keys_localAINotReadyTextFieldPrompt.tr();
    } else {
      hintText = LocaleKeys.chat_inputLocalAIMessageHint.tr();
      tooltip = null;
    }

    return AIModelState(
      type: AiType.local,
      hintText: hintText,
      tooltip: tooltip,
      isEditable: enabled && running,
      localAIEnabled: enabled,
      supportChatWithFile: localAIState.isVault,
    );
  }
}
