import 'dart:async';

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
import 'package:appflowy_result/appflowy_result.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:fixnum/fixnum.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:protobuf/protobuf.dart';

part 'settings_workspace_sub_billing_bloc.freezed.dart';

class SettingsWorkspaceSubscriptionBillingBloc extends Bloc<
    SettingsWorkspaceSubscriptionBillingEvent,
    SettingsWorkspaceSubscriptionBillingState> {
  SettingsWorkspaceSubscriptionBillingBloc({
    required this.workspaceId,
    required Int64 userId,
  }) : super(const _Initial()) {
    _userService = UserBackendService(userId: userId);
    _service = WorkspaceService(workspaceId: workspaceId, userId: userId);
    _successListenable = getIt<SubscriptionSuccessListenable>();
    _successListenable.addListener(_onSubscriptionPaymentSuccessful);

    on<_Started>(_onStarted);
    on<_BillingPortalFetched>(_onBillingPortalFetched);
    on<_OpenCustomerPortal>(_onOpenCustomerPortal);
    on<_AddSubscription>(_onAddSubscription);
    on<_CancelSubscription>(_onCancelSubscription);
    on<_PaymentSuccessful>(_onPaymentSuccessful);
    on<_UpdatePeriod>(_onUpdatePeriod);
  }

  late final String workspaceId;
  late final WorkspaceService _service;
  late final UserBackendService _userService;
  late final SubscriptionSuccessListenable _successListenable;

  final _billingPortalCompleter =
      Completer<FlowyResult<BillingPortalPB, FlowyError>>();
  BillingPortalPB? _billingPortal;

  @override
  Future<void> close() {
    _successListenable.removeListener(_onSubscriptionPaymentSuccessful);
    return super.close();
  }

  // Event Handlers

  Future<void> _onStarted(
    _Started event,
    Emitter<SettingsWorkspaceSubscriptionBillingState> emit,
  ) async {
    emit(const SettingsWorkspaceSubscriptionBillingState.loading());

    final subscriptionInfo = await _fetchSubscriptionInfo();
    if (subscriptionInfo == null) {
      return;
    }

    _initializeBillingPortal();

    emit(
      SettingsWorkspaceSubscriptionBillingState.ready(
        subscriptionInfo: subscriptionInfo,
        billingPortal: _billingPortal,
      ),
    );
  }

  Future<void> _onBillingPortalFetched(
    _BillingPortalFetched event,
    Emitter<SettingsWorkspaceSubscriptionBillingState> emit,
  ) async {
    state.maybeWhen(
      orElse: () {},
      ready: (subscriptionInfo, _, plan, isLoading) => emit(
        SettingsWorkspaceSubscriptionBillingState.ready(
          subscriptionInfo: subscriptionInfo,
          billingPortal: event.billingPortal,
          successfulPlanUpgrade: plan,
          isLoading: isLoading,
        ),
      ),
    );
  }

  Future<void> _onOpenCustomerPortal(
    _OpenCustomerPortal event,
    Emitter<SettingsWorkspaceSubscriptionBillingState> emit,
  ) async {
    await _ensureBillingPortalReady();
    if (_billingPortal != null) {
      await afLaunchUrlString(_billingPortal!.url);
    }
  }

  Future<void> _onAddSubscription(
    _AddSubscription event,
    Emitter<SettingsWorkspaceSubscriptionBillingState> emit,
  ) async {
    final result =
        await _userService.createSubscription(workspaceId, event.plan);
    result.fold(
      (link) => afLaunchUrlString(link.paymentLink),
      (error) => Log.error(error.msg, error),
    );
  }

  Future<void> _onCancelSubscription(
    _CancelSubscription event,
    Emitter<SettingsWorkspaceSubscriptionBillingState> emit,
  ) async {
    final currentState = _getReadyState();
    if (currentState == null) return;

    emit(currentState.copyWith(isLoading: true));

    final success = await _cancelSubscription(event.plan, event.reason);
    if (!success) {
      emit(currentState.copyWith(isLoading: false));
      return;
    }

    final updatedInfo = _updateSubscriptionInfoAfterCancellation(
      currentState.subscriptionInfo,
      event.plan,
    );

    emit(
      SettingsWorkspaceSubscriptionBillingState.ready(
        subscriptionInfo: updatedInfo,
        billingPortal: _billingPortal,
      ),
    );
  }

  Future<void> _onPaymentSuccessful(
    _PaymentSuccessful event,
    Emitter<SettingsWorkspaceSubscriptionBillingState> emit,
  ) async {
    final subscriptionInfo = await _fetchSubscriptionInfo();
    if (subscriptionInfo != null) {
      emit(
        SettingsWorkspaceSubscriptionBillingState.ready(
          subscriptionInfo: subscriptionInfo,
          billingPortal: _billingPortal,
        ),
      );
    }
  }

  Future<void> _onUpdatePeriod(
    _UpdatePeriod event,
    Emitter<SettingsWorkspaceSubscriptionBillingState> emit,
  ) async {
    final currentState = _getReadyState();
    if (currentState == null) return;

    emit(currentState.copyWith(isLoading: true));

    final success = await _updateSubscriptionPeriod(event.plan, event.interval);
    if (!success) {
      emit(currentState.copyWith(isLoading: false));
      return;
    }

    final subscriptionInfo = await _fetchSubscriptionInfo();
    if (subscriptionInfo != null) {
      emit(
        SettingsWorkspaceSubscriptionBillingState.ready(
          subscriptionInfo: subscriptionInfo,
          billingPortal: _billingPortal,
        ),
      );
    }
  }

  // Helper Methods

  Future<WorkspaceSubscriptionInfoPB?> _fetchSubscriptionInfo() async {
    final result =
        await UserBackendService.getWorkspaceSubscriptionInfo(workspaceId);
    return result.fold(
      (info) => info,
      (error) {
        add(
          SettingsWorkspaceSubscriptionBillingEvent.started(),
        );
        Log.error('Failed to fetch subscription info', error);
        return null;
      },
    );
  }

  void _initializeBillingPortal() {
    if (!_billingPortalCompleter.isCompleted) {
      unawaited(_fetchBillingPortal());
      unawaited(
        _billingPortalCompleter.future.then(
          (result) {
            if (isClosed) return;
            result.fold(
              (portal) {
                _billingPortal = portal;
                add(
                  SettingsWorkspaceSubscriptionBillingEvent
                      .billingPortalFetched(
                    billingPortal: portal,
                  ),
                );
              },
              (error) => Log.error('Error fetching billing portal: $error'),
            );
          },
        ),
      );
    }
  }

  Future<void> _fetchBillingPortal() async {
    final billingPortalResult = await _service.getBillingPortal();
    _billingPortalCompleter.complete(billingPortalResult);
  }

  Future<void> _ensureBillingPortalReady() async {
    if (_billingPortalCompleter.isCompleted && _billingPortal != null) {
      return;
    }
    await _billingPortalCompleter.future;
  }

  Future<bool> _cancelSubscription(
    SubscriptionPlanPB plan,
    String? reason,
  ) async {
    final result = await _userService.cancelWorkspaceSubscription(
      workspaceId,
      plan,
      reason,
    );

    return result.fold(
      (_) => true,
      (error) {
        Log.error(
          'Failed to cancel subscription of ${plan.label}: ${error.msg}',
          error,
        );
        return false;
      },
    );
  }

  Future<bool> _updateSubscriptionPeriod(
    SubscriptionPlanPB plan,
    RecurringIntervalPB interval,
  ) async {
    final result = await _userService.updateWorkspaceSubscriptionPeriod(
      workspaceId,
      plan,
      interval,
    );

    return result.fold(
      (_) => true,
      (error) {
        Log.error(
          'Failed to update subscription period of ${plan.label}: ${error.msg}',
          error,
        );
        return false;
      },
    );
  }

  WorkspaceSubscriptionInfoPB _updateSubscriptionInfoAfterCancellation(
    WorkspaceSubscriptionInfoPB info,
    SubscriptionPlanPB cancelledPlan,
  ) {
    info.freeze();
    return info.rebuild((value) {
      if (cancelledPlan.isAddOn) {
        value.addOns.removeWhere(
          (addon) => addon.addOnSubscription.subscriptionPlan == cancelledPlan,
        );
      } else if (_shouldDowngradeToFree(cancelledPlan, value.plan)) {
        value.plan = SubscriptionPlanPB.Free;
        value.subscription.freeze();
        value.subscription = value.subscription.rebuild((sub) {
          sub.status = SubscriptionStatusPB.Active;
          sub.subscriptionPlan = SubscriptionPlanPB.Free;
        });
      }
    });
  }

  bool _shouldDowngradeToFree(
    SubscriptionPlanPB cancelledPlan,
    SubscriptionPlanPB currentPlan,
  ) {
    return cancelledPlan == SubscriptionPlanPB.Pro &&
        currentPlan == SubscriptionPlanPB.Pro;
  }

  _Ready? _getReadyState() {
    return state.mapOrNull(ready: (s) => s);
  }

  Future<void> _onSubscriptionPaymentSuccessful() async {
    add(
      SettingsWorkspaceSubscriptionBillingEvent.paymentSuccessful(
        plan: _successListenable.workspaceSubscriptionPlan,
      ),
    );
  }
}

@freezed
class SettingsWorkspaceSubscriptionBillingEvent
    with _$SettingsWorkspaceSubscriptionBillingEvent {
  const factory SettingsWorkspaceSubscriptionBillingEvent.started() = _Started;

  const factory SettingsWorkspaceSubscriptionBillingEvent.billingPortalFetched({
    required BillingPortalPB billingPortal,
  }) = _BillingPortalFetched;

  const factory SettingsWorkspaceSubscriptionBillingEvent.openCustomerPortal() =
      _OpenCustomerPortal;

  const factory SettingsWorkspaceSubscriptionBillingEvent.addSubscription(
    SubscriptionPlanPB plan,
  ) = _AddSubscription;

  const factory SettingsWorkspaceSubscriptionBillingEvent.cancelSubscription(
    SubscriptionPlanPB plan, {
    @Default(null) String? reason,
  }) = _CancelSubscription;

  const factory SettingsWorkspaceSubscriptionBillingEvent.paymentSuccessful({
    SubscriptionPlanPB? plan,
  }) = _PaymentSuccessful;

  const factory SettingsWorkspaceSubscriptionBillingEvent.updatePeriod({
    required SubscriptionPlanPB plan,
    required RecurringIntervalPB interval,
  }) = _UpdatePeriod;
}

@freezed
class SettingsWorkspaceSubscriptionBillingState extends Equatable
    with _$SettingsWorkspaceSubscriptionBillingState {
  const SettingsWorkspaceSubscriptionBillingState._();

  const factory SettingsWorkspaceSubscriptionBillingState.initial() = _Initial;

  const factory SettingsWorkspaceSubscriptionBillingState.loading() = _Loading;

  const factory SettingsWorkspaceSubscriptionBillingState.error({
    @Default(null) FlowyError? error,
  }) = _Error;

  const factory SettingsWorkspaceSubscriptionBillingState.ready({
    required WorkspaceSubscriptionInfoPB subscriptionInfo,
    required BillingPortalPB? billingPortal,
    @Default(null) SubscriptionPlanPB? successfulPlanUpgrade,
    @Default(false) bool isLoading,
  }) = _Ready;

  @override
  List<Object?> get props => maybeWhen(
        orElse: () => const [],
        error: (error) => [error],
        ready: (subscription, billingPortal, plan, isLoading) => [
          subscription,
          billingPortal,
          plan,
          isLoading,
          ...subscription.addOns,
        ],
      );
}
