import 'dart:async';

import 'package:appflowy/workspace/application/settings/plan/workspace_subscription_ext.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:flutter/foundation.dart';

import 'package:appflowy/core/helpers/url_launcher.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/user/application/user_service.dart';
import 'package:appflowy/workspace/application/subscription_success_listenable/subscription_success_listenable.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:fixnum/fixnum.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:protobuf/protobuf.dart';

part 'settings_personal_sub_billing_bloc.freezed.dart';

class SettingsPersonalSubscriptionBillingBloc extends Bloc<
    SettingsPersonalSubscriptionBillingEvent,
    SettingsPersonalSubscriptionBillingState> {
  SettingsPersonalSubscriptionBillingBloc({
    required Int64 userId,
  }) : super(const _Initial()) {
    _userService = UserBackendService(userId: userId);
    _successListenable = getIt<SubscriptionSuccessListenable>();
    _successListenable.addListener(_onSubscriptionPaymentSuccessful);

    on<_Started>(_onStarted);
    on<_AddSubscription>(_onAddSubscription);
    on<_CancelSubscription>(_onCancelSubscription);
    on<_PaymentSuccessful>(_onPaymentSuccessful);
    on<_DidLoadSubscriptionInfo>(_onDidLoadSubscriptionInfo);
  }

  late final UserBackendService _userService;
  late final SubscriptionSuccessListenable _successListenable;

  @override
  Future<void> close() {
    _successListenable.removeListener(_onSubscriptionPaymentSuccessful);
    return super.close();
  }

  // Event Handlers

  Future<void> _onStarted(
    _Started event,
    Emitter<SettingsPersonalSubscriptionBillingState> emit,
  ) async {
    emit(const SettingsPersonalSubscriptionBillingState.loading());

    await _fetchSubscriptionInfo();
  }

  Future<void> _onAddSubscription(
    _AddSubscription event,
    Emitter<SettingsPersonalSubscriptionBillingState> emit,
  ) async {
    final currentState = _getReadyState();
    if (currentState == null) return;

    emit(currentState.copyWith(isLoading: true));

    final result = await _userService.createPersonalSubscription(event.plan);

    result.fold(
      (link) => afLaunchUrlString(link.paymentLink),
      (error) => Log.error(error.msg, error),
    );

    // Reset loading state
    emit(currentState.copyWith(isLoading: false));
  }

  Future<void> _onCancelSubscription(
    _CancelSubscription event,
    Emitter<SettingsPersonalSubscriptionBillingState> emit,
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
      SettingsPersonalSubscriptionBillingState.ready(
        subscriptionInfo: updatedInfo,
        subscriptionState: updatedInfo.subscriptionState,
      ),
    );
  }

  Future<void> _onPaymentSuccessful(
    _PaymentSuccessful event,
    Emitter<SettingsPersonalSubscriptionBillingState> emit,
  ) async {
    await _fetchSubscriptionInfo();
  }

  Future<void> _onDidLoadSubscriptionInfo(
    _DidLoadSubscriptionInfo event,
    Emitter<SettingsPersonalSubscriptionBillingState> emit,
  ) async {
    event.result.fold(
      (info) => emit(
        SettingsPersonalSubscriptionBillingState.ready(
          subscriptionInfo: info,
          subscriptionState: info.subscriptionState,
        ),
      ),
      (error) => {},
    );
  }

  // Helper Methods

  Future<void> _fetchSubscriptionInfo() async {
    final result = await UserBackendService.refreshPersonalSubscription();
    if (isClosed) return;
    add(
      SettingsPersonalSubscriptionBillingEvent.didLoadSubscriptionInfo(
        result,
      ),
    );
  }

  Future<bool> _cancelSubscription(
    PersonalPlanPB plan,
    String? reason,
  ) async {
    final result = await _userService.cancelPersonalSubscription(
      plan,
      reason,
    );

    return result.fold(
      (_) => true,
      (error) {
        Log.error(
          'Failed to cancel personal subscription of ${plan.name}: ${error.msg}',
          error,
        );
        return false;
      },
    );
  }

  PersonalSubscriptionInfoPB _updateSubscriptionInfoAfterCancellation(
    PersonalSubscriptionInfoPB info,
    PersonalPlanPB cancelledPlan,
  ) {
    info.freeze();
    return info.rebuild((value) {
      value.subscriptions.removeWhere(
        (subscription) => subscription.plan == cancelledPlan,
      );
    });
  }

  _Ready? _getReadyState() {
    return state.mapOrNull(ready: (s) => s);
  }

  Future<void> _onSubscriptionPaymentSuccessful() async {
    add(
      const SettingsPersonalSubscriptionBillingEvent.paymentSuccessful(),
    );
  }
}

@freezed
class SettingsPersonalSubscriptionBillingEvent
    with _$SettingsPersonalSubscriptionBillingEvent {
  const factory SettingsPersonalSubscriptionBillingEvent.started() = _Started;

  const factory SettingsPersonalSubscriptionBillingEvent.didLoadSubscriptionInfo(
    FlowyResult<PersonalSubscriptionInfoPB, FlowyError> result,
  ) = _DidLoadSubscriptionInfo;

  const factory SettingsPersonalSubscriptionBillingEvent.addSubscription(
    PersonalPlanPB plan,
  ) = _AddSubscription;

  const factory SettingsPersonalSubscriptionBillingEvent.cancelSubscription(
    PersonalPlanPB plan, {
    @Default(null) String? reason,
  }) = _CancelSubscription;

  const factory SettingsPersonalSubscriptionBillingEvent.paymentSuccessful() =
      _PaymentSuccessful;
}

@freezed
class SettingsPersonalSubscriptionBillingState extends Equatable
    with _$SettingsPersonalSubscriptionBillingState {
  const SettingsPersonalSubscriptionBillingState._();

  const factory SettingsPersonalSubscriptionBillingState.initial() = _Initial;

  const factory SettingsPersonalSubscriptionBillingState.loading() = _Loading;

  const factory SettingsPersonalSubscriptionBillingState.ready({
    required PersonalSubscriptionInfoPB subscriptionInfo,
    @Default(false) bool isLoading,
    @Default(SubscriptionState.newSubscription)
    SubscriptionState subscriptionState,
  }) = _Ready;

  PersonalSubscriptionPB get subscription {
    return mapOrNull(
          ready: (state) {
            return state.subscriptionInfo.subscriptions
                    .where((sub) => sub.plan == PersonalPlanPB.VaultWorkspace)
                    .firstOrNull ??
                PersonalSubscriptionPB();
          },
        ) ??
        PersonalSubscriptionPB();
  }

  @override
  List<Object?> get props => maybeWhen(
        orElse: () => const [],
        ready: (subscriptionInfo, isLoading, subscriptionState) => [
          subscriptionInfo,
          isLoading,
          subscriptionState,
          ...subscriptionInfo.subscriptions,
        ],
      );
}
