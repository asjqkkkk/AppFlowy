import 'package:flutter/foundation.dart';

import 'package:appflowy/core/helpers/url_launcher.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/user/application/user_service.dart';
import 'package:appflowy/workspace/application/settings/plan/workspace_subscription_ext.dart';
import 'package:appflowy/workspace/application/subscription_success_listenable/subscription_success_listenable.dart';
import 'package:appflowy/workspace/application/workspace/workspace_service.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:bloc/bloc.dart';
import 'package:fixnum/fixnum.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:protobuf/protobuf.dart';

part 'settings_plan_bloc.freezed.dart';

class SettingsPlanBloc extends Bloc<SettingsPlanEvent, SettingsPlanState> {
  SettingsPlanBloc({
    required this.workspaceId,
    required Int64 userId,
  })  : _service = WorkspaceService(
          workspaceId: workspaceId,
          userId: userId,
        ),
        _userService = UserBackendService(userId: userId),
        _successListenable = getIt<SubscriptionSuccessListenable>(),
        super(const SettingsPlanState.initial()) {
    on<_Started>(_onStarted);
    on<_AddSubscription>(_onAddSubscription);
    on<_CancelSubscription>(_onCancelSubscription);
    on<_PaymentSuccessful>(_onPaymentSuccessful);

    // Add listener for payment success
    _successListenable.addListener(_onPaymentSuccessfulCallback);
  }

  final String workspaceId;
  final WorkspaceService _service;
  final IUserBackendService _userService;
  final SubscriptionSuccessListenable _successListenable;

  // Cached data to avoid unnecessary API calls
  WorkspaceUsagePB? _cachedWorkspaceUsage;
  WorkspaceSubscriptionInfoPB? _cachedWorkspaceSubscriptionInfo;

  Future<void> _onStarted(
    _Started event,
    Emitter<SettingsPlanState> emit,
  ) async {
    try {
      // Only show loading if explicitly requested and not using cache
      if (event.shouldLoad &&
          (_cachedWorkspaceUsage == null ||
              _cachedWorkspaceSubscriptionInfo == null)) {
        emit(const SettingsPlanState.loading());
      }

      // Fetch data or use cache
      final data = await _fetchSubscriptionData();

      if (data == null) {
        emit(
          SettingsPlanState.error(
            error: FlowyError(msg: 'Failed to fetch subscription data'),
          ),
        );
        return;
      }

      final (usage, subscriptionInfo) = data;

      // Cache the data
      _cachedWorkspaceUsage = usage;
      _cachedWorkspaceSubscriptionInfo = subscriptionInfo;

      emit(
        SettingsPlanState.ready(
          workspaceUsage: usage,
          subscriptionInfo: subscriptionInfo,
          successfulPlanUpgrade: event.withSuccessfulUpgrade,
        ),
      );

      // Clear the success notification after showing it
      if (event.withSuccessfulUpgrade != null) {
        await Future.delayed(const Duration(milliseconds: 100));
        emit(
          SettingsPlanState.ready(
            workspaceUsage: usage,
            subscriptionInfo: subscriptionInfo,
          ),
        );
      }
    } catch (e) {
      Log.error('Failed to load subscription data', e);
      emit(
        SettingsPlanState.error(
          error: FlowyError(msg: 'Unexpected error: ${e.toString()}'),
        ),
      );
    }
  }

  Future<void> _onAddSubscription(
    _AddSubscription event,
    Emitter<SettingsPlanState> emit,
  ) async {
    try {
      final result = await _userService.createSubscription(
        workspaceId,
        event.plan,
      );

      await result.fold(
        (paymentLink) async => afLaunchUrlString(paymentLink.paymentLink),
        (error) {
          Log.error(
            'Failed to fetch payment link for ${event.plan}: ${error.msg}',
            error,
          );
          // Optionally emit an error state
          _emitErrorIfReady(emit, error);
        },
      );
    } catch (e) {
      Log.error('Failed to add subscription', e);
      _emitErrorIfReady(
        emit,
        FlowyError(msg: 'Failed to add subscription: ${e.toString()}'),
      );
    }
  }

  Future<void> _onCancelSubscription(
    _CancelSubscription event,
    Emitter<SettingsPlanState> emit,
  ) async {
    final readyState = state.mapOrNull(ready: (s) => s);
    if (readyState == null) return;

    try {
      // Show processing state
      emit(readyState.copyWith(downgradeProcessing: true));

      final result = await _userService.cancelWorkspaceSubscription(
        workspaceId,
        SubscriptionPlanPB.Pro,
        event.reason,
      );

      await result.fold(
        (_) async {
          // Update the state with downgraded subscription
          final updatedState = _createDowngradedState(readyState);
          if (updatedState != null) {
            emit(updatedState);
            // Invalidate cache to force refresh on next load
            _invalidateCache();
          }
        },
        (error) {
          Log.error('Failed to cancel subscription: ${error.msg}', error);
          // Revert to original state without processing flag
          emit(readyState.copyWith(downgradeProcessing: false));
        },
      );
    } catch (e) {
      Log.error('Failed to cancel subscription', e);
      emit(readyState.copyWith(downgradeProcessing: false));
    }
  }

  // Helper method to fetch subscription data
  Future<(WorkspaceUsagePB, WorkspaceSubscriptionInfoPB)?>
      _fetchSubscriptionData() async {
    try {
      final results = await Future.wait([
        _service.getWorkspaceUsage(),
        UserBackendService.getWorkspaceSubscriptionInfo(workspaceId),
      ]);

      WorkspaceUsagePB? usage;
      WorkspaceSubscriptionInfoPB? subscriptionInfo;
      FlowyError? error;

      usage = results[0].fold(
        (s) => s as WorkspaceUsagePB,
        (e) {
          error = e;
          return null;
        },
      );

      subscriptionInfo = results[1].fold(
        (s) => s as WorkspaceSubscriptionInfoPB,
        (e) {
          error = e;
          return null;
        },
      );

      if (usage == null || subscriptionInfo == null) {
        Log.error('Failed to fetch subscription data', error);
        return null;
      }

      return (usage, subscriptionInfo);
    } catch (e) {
      Log.error('Error fetching subscription data', e);
      return null;
    }
  }

  // Helper method to create downgraded state
  _Ready? _createDowngradedState(_Ready currentState) {
    try {
      final subscriptionInfo = currentState.subscriptionInfo;
      final usage = currentState.workspaceUsage;

      // Create new subscription info with Free plan
      subscriptionInfo.freeze();
      final newInfo = subscriptionInfo.rebuild((value) {
        value.plan = SubscriptionPlanPB.Free;
        value.subscription.freeze();
        value.subscription = value.subscription.rebuild((sub) {
          sub.status = SubscriptionStatusPB.Active;
          sub.subscriptionPlan = SubscriptionPlanPB.Free;
        });
      });

      // Update usage limits based on new plan
      usage.freeze();
      final newUsage = usage.rebuild((value) {
        if (!newInfo.hasAIMax) {
          value.aiResponsesUnlimited = false;
        }
        value.storageBytesUnlimited = false;
      });

      return SettingsPlanState.ready(
        subscriptionInfo: newInfo,
        workspaceUsage: newUsage,
      ) as _Ready;
    } catch (e) {
      Log.error('Failed to create downgraded state', e);
      return null;
    }
  }

  // Helper method to emit error state if in ready state
  void _emitErrorIfReady(Emitter<SettingsPlanState> emit, FlowyError error) {
    final readyState = state.mapOrNull(ready: (s) => s);
    if (readyState != null) {
      // Temporarily show error without losing current data
      emit(SettingsPlanState.error(error: error));
      // Restore ready state after a delay
      Future.delayed(const Duration(seconds: 3), () {
        if (!emit.isDone) {
          emit(readyState);
        }
      });
    }
  }

  void _invalidateCache() {
    _cachedWorkspaceUsage = null;
    _cachedWorkspaceSubscriptionInfo = null;
  }

  void _onPaymentSuccessfulCallback() {
    add(
      SettingsPlanEvent.paymentSuccessful(
        plan: _successListenable.workspaceSubscriptionPlan,
      ),
    );
  }

  Future<void> _onPaymentSuccessful(
    _PaymentSuccessful event,
    Emitter<SettingsPlanState> emit,
  ) async {
    if (state is! _Ready) return;

    // Invalidate cache to force fresh data
    _invalidateCache();

    // Reload with the successful upgrade flag
    add(
      SettingsPlanEvent.started(
        withSuccessfulUpgrade: event.plan,
        shouldLoad: false,
      ),
    );
  }

  @override
  Future<void> close() {
    _successListenable.removeListener(_onPaymentSuccessfulCallback);
    return super.close();
  }
}

@freezed
class SettingsPlanEvent with _$SettingsPlanEvent {
  const factory SettingsPlanEvent.started({
    SubscriptionPlanPB? withSuccessfulUpgrade,
    @Default(true) bool shouldLoad,
  }) = _Started;

  const factory SettingsPlanEvent.addSubscription(SubscriptionPlanPB plan) =
      _AddSubscription;

  const factory SettingsPlanEvent.cancelSubscription({
    String? reason,
  }) = _CancelSubscription;

  const factory SettingsPlanEvent.paymentSuccessful({
    SubscriptionPlanPB? plan,
  }) = _PaymentSuccessful;
}

@freezed
class SettingsPlanState with _$SettingsPlanState {
  const factory SettingsPlanState.initial() = _Initial;

  const factory SettingsPlanState.loading() = _Loading;

  const factory SettingsPlanState.error({
    required FlowyError error,
  }) = _Error;

  const factory SettingsPlanState.ready({
    required WorkspaceUsagePB workspaceUsage,
    required WorkspaceSubscriptionInfoPB subscriptionInfo,
    SubscriptionPlanPB? successfulPlanUpgrade,
    @Default(false) bool downgradeProcessing,
  }) = _Ready;
}
