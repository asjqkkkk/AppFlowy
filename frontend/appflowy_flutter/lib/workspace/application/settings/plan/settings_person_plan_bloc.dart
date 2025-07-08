import 'package:flutter/foundation.dart';

import 'package:appflowy/core/helpers/url_launcher.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/user/application/user_service.dart';
import 'package:appflowy/workspace/application/subscription_success_listenable/subscription_success_listenable.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:bloc/bloc.dart';
import 'package:fixnum/fixnum.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:protobuf/protobuf.dart';

part 'settings_person_plan_bloc.freezed.dart';

class SettingsPersonPlanBloc
    extends Bloc<SettingsPersonPlanEvent, SettingsPersonPlanState> {
  SettingsPersonPlanBloc({
    required Int64 userId,
  })  : _userService = UserBackendService(userId: userId),
        _successListenable = getIt<SubscriptionSuccessListenable>(),
        super(const SettingsPersonPlanState.initial()) {
    on<_Started>(_onStarted);
    on<_AddSubscription>(_onAddSubscription);
    on<_CancelSubscription>(_onCancelSubscription);
    on<_PaymentSuccessful>(_onPaymentSuccessful);

    // Add listener for payment success
    _successListenable.addListener(_onPaymentSuccessfulCallback);
  }

  final IUserBackendService _userService;
  final SubscriptionSuccessListenable _successListenable;

  // Cached data to avoid unnecessary API calls
  PersonalSubscriptionInfoPB? _cachedSubscription;

  Future<void> _onStarted(
    _Started event,
    Emitter<SettingsPersonPlanState> emit,
  ) async {
    try {
      // Only show loading if explicitly requested and not using cache
      if (event.shouldLoad && _cachedSubscription == null) {
        emit(const SettingsPersonPlanState.loading());
      }

      // Fetch data or use cache
      final result = await UserBackendService.refreshPersonalSubscription();
      await result.fold(
        (subscriptionInfo) async {
          _cachedSubscription = subscriptionInfo;

          emit(
            SettingsPersonPlanState.ready(
              subscriptionInfo: subscriptionInfo,
              successfulPlanUpgrade: event.withSuccessfulUpgrade,
            ),
          );

          // Clear the success notification after showing it
          if (event.withSuccessfulUpgrade != null) {
            emit(
              SettingsPersonPlanState.ready(
                subscriptionInfo: subscriptionInfo,
              ),
            );
          }
        },
        (error) {
          emit(
            SettingsPersonPlanState.error(
              error: error,
            ),
          );
        },
      );
    } catch (e) {
      emit(
        SettingsPersonPlanState.error(
          error: FlowyError(msg: 'Unexpected error: ${e.toString()}'),
        ),
      );
    }
  }

  Future<void> _onAddSubscription(
    _AddSubscription event,
    Emitter<SettingsPersonPlanState> emit,
  ) async {
    try {
      final result = await _userService.createPersonalSubscription(
        event.plan,
      );

      await result.fold(
        (paymentLink) async => afLaunchUrlString(paymentLink.paymentLink),
        (error) {
          _emitErrorIfReady(emit, error);
        },
      );
    } catch (e) {
      _emitErrorIfReady(
        emit,
        FlowyError(msg: 'Failed to add subscription: ${e.toString()}'),
      );
    }
  }

  Future<void> _onCancelSubscription(
    _CancelSubscription event,
    Emitter<SettingsPersonPlanState> emit,
  ) async {
    final readyState = state.mapOrNull(ready: (s) => s);
    if (readyState == null) return;

    try {
      // Show processing state
      emit(readyState.copyWith(downgradeProcessing: true));

      final result = await _userService.cancelPersonalSubscription(
        event.plan,
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
          Log.error(
            'Failed to cancel personal subscription: ${error.msg}',
            error,
          );
          // Revert to original state without processing flag
          emit(readyState.copyWith(downgradeProcessing: false));
        },
      );
    } catch (e) {
      Log.error('Failed to cancel personal subscription', e);
      emit(readyState.copyWith(downgradeProcessing: false));
    }
  }

  // Helper method to create downgraded state
  _Ready? _createDowngradedState(_Ready currentState) {
    try {
      final subscriptionInfo = currentState.subscriptionInfo;

      // Create new subscription info with Free plan
      subscriptionInfo.freeze();
      final newInfo = subscriptionInfo.rebuild((value) {
        value.subscriptions.clear();
      });

      return SettingsPersonPlanState.ready(
        subscriptionInfo: newInfo,
      ) as _Ready;
    } catch (e) {
      Log.error('Failed to create downgraded state', e);
      return null;
    }
  }

  // Helper method to emit error state if in ready state
  void _emitErrorIfReady(
    Emitter<SettingsPersonPlanState> emit,
    FlowyError error,
  ) {
    final readyState = state.mapOrNull(ready: (s) => s);
    if (readyState != null) {
      // Temporarily show error without losing current data
      emit(SettingsPersonPlanState.error(error: error));
      // Restore ready state after a delay
      Future.delayed(const Duration(seconds: 3), () {
        if (!emit.isDone) {
          emit(readyState);
        }
      });
    }
  }

  void _invalidateCache() {
    _cachedSubscription = null;
  }

  void _onPaymentSuccessfulCallback() {
    add(
      SettingsPersonPlanEvent.paymentSuccessful(
        plan: _successListenable.personalSubscriptionPlan,
      ),
    );
  }

  Future<void> _onPaymentSuccessful(
    _PaymentSuccessful event,
    Emitter<SettingsPersonPlanState> emit,
  ) async {
    if (state is! _Ready) return;

    // Invalidate cache to force fresh data
    _invalidateCache();

    // Reload with the successful upgrade flag
    add(
      SettingsPersonPlanEvent.started(
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
class SettingsPersonPlanEvent with _$SettingsPersonPlanEvent {
  const factory SettingsPersonPlanEvent.started({
    PersonalPlanPB? withSuccessfulUpgrade,
    @Default(true) bool shouldLoad,
  }) = _Started;

  const factory SettingsPersonPlanEvent.addSubscription(PersonalPlanPB plan) =
      _AddSubscription;

  const factory SettingsPersonPlanEvent.cancelSubscription({
    required PersonalPlanPB plan,
    String? reason,
  }) = _CancelSubscription;

  const factory SettingsPersonPlanEvent.paymentSuccessful({
    PersonalPlanPB? plan,
  }) = _PaymentSuccessful;
}

@freezed
class SettingsPersonPlanState with _$SettingsPersonPlanState {
  const factory SettingsPersonPlanState.initial() = _Initial;

  const factory SettingsPersonPlanState.loading() = _Loading;

  const factory SettingsPersonPlanState.error({
    required FlowyError error,
  }) = _Error;

  const factory SettingsPersonPlanState.ready({
    required PersonalSubscriptionInfoPB subscriptionInfo,
    PersonalPlanPB? successfulPlanUpgrade,
    @Default(false) bool downgradeProcessing,
  }) = _Ready;
}
