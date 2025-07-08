import 'dart:async';

import 'package:appflowy/core/helpers/url_launcher.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/user/application/user_service.dart';
import 'package:appflowy/workspace/application/subscription_success_listenable/subscription_success_listenable.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-ai/entities.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/billing.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:bloc/bloc.dart';
import 'package:fixnum/fixnum.dart';
import 'package:protobuf/protobuf.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'local_llm_listener.dart';

part 'local_ai_bloc.freezed.dart';

class LocalAISettingBloc
    extends Bloc<LocalAISettingEvent, LocalAISettingState> {
  LocalAISettingBloc({required Int64 userId}) : super(const _Loading()) {
    _userService = UserBackendService(userId: userId);
    _successListenable = getIt<SubscriptionSuccessListenable>();
    _successListenable.addListener(_onSubscriptionPaymentSuccessful);

    on<LocalAISettingEvent>(_handleEvent);
    _startListening();
    _getLocalAiState();
  }

  final listener = LocalAIStateListener();
  late final SubscriptionSuccessListenable _successListenable;
  late final UserBackendService _userService;

  @override
  Future<void> close() async {
    await listener.stop();
    return super.close();
  }

  Future<void> _handleEvent(
    LocalAISettingEvent event,
    Emitter<LocalAISettingState> emit,
  ) async {
    if (isClosed) {
      return;
    }

    await event.when(
      didReceiveAiState: (data) {
        emit(
          LocalAISettingState.ready(data: data),
        );
      },
      didReceiveLackOfResources: (resources) {
        state.maybeMap(
          ready: (readyState) {
            readyState.data.freeze();
            final data =
                readyState.data.rebuild((p0) => p0.lackOfResource = resources);
            emit(
              LocalAISettingState.ready(
                data: data,
              ),
            );
          },
          orElse: () {},
        );
      },
      toggle: () async {
        emit(LocalAISettingState.loading());
        await AIEventToggleLocalAI().send().fold(
          (aiState) {
            if (!isClosed) {
              add(LocalAISettingEvent.didReceiveAiState(aiState));
            }
          },
          Log.error,
        );
      },
      restart: () async {
        emit(LocalAISettingState.loading());
        await AIEventRestartLocalAI().send();
      },
      paymentSuccessful: () async {
        final result = await UserBackendService.refreshPersonalSubscription();
        return result.fold(
          (info) => _getLocalAiState(),
          (error) {
            Log.error('Failed to fetch personal subscription info', error);
            return null;
          },
        );
      },
      addSubscription: (PersonalPlanPB plan) async {
        final result = await _userService.createPersonalSubscription(plan);
        result.fold(
          (link) => afLaunchUrlString(link.paymentLink),
          (error) => Log.error(error.msg, error),
        );
      },
    );
  }

  void _startListening() {
    listener.start(
      stateCallback: (pluginState) {
        if (!isClosed) {
          add(LocalAISettingEvent.didReceiveAiState(pluginState));
        }
      },
      resourceCallback: (data) {
        if (!isClosed) {
          add(LocalAISettingEvent.didReceiveLackOfResources(data));
        }
      },
    );
  }

  void _getLocalAiState() {
    AIEventGetLocalAIState().send().fold(
      (aiState) {
        if (!isClosed) {
          if (aiState.isVault) {
            UserBackendService.refreshPersonalSubscription();
          }

          add(LocalAISettingEvent.didReceiveAiState(aiState));
        }
      },
      Log.error,
    );
  }

  Future<void> _onSubscriptionPaymentSuccessful() async {
    add(
      const LocalAISettingEvent.paymentSuccessful(),
    );
  }
}

@freezed
class LocalAISettingEvent with _$LocalAISettingEvent {
  const factory LocalAISettingEvent.didReceiveAiState(LocalAIStatePB aiState) =
      _DidReceiveAiState;
  const factory LocalAISettingEvent.didReceiveLackOfResources(
    LackOfAIResourcePB resources,
  ) = _DidReceiveLackOfResources;

  const factory LocalAISettingEvent.addSubscription(PersonalPlanPB plan) =
      _AddSubscription;
  const factory LocalAISettingEvent.paymentSuccessful() = _PaymentSuccessful;
  const factory LocalAISettingEvent.toggle() = _Toggle;
  const factory LocalAISettingEvent.restart() = _Restart;
}

@freezed
class LocalAISettingState with _$LocalAISettingState {
  const LocalAISettingState._();

  const factory LocalAISettingState.ready({
    required LocalAIStatePB data,
  }) = _Ready;

  const factory LocalAISettingState.loading() = _Loading;

  LocalAIStatePB? get data {
    return maybeWhen(
      ready: (data) => data,
      orElse: () => null,
    );
  }

  bool get isVault {
    return data?.isVault ?? false;
  }

  bool get isToggleOn {
    return data?.toggleOn ?? false;
  }

  bool get isEnabled {
    return data?.enabled ?? false;
  }
}
