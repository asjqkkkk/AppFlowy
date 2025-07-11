import 'dart:async';

import 'package:appflowy/workspace/application/settings/plan/workspace_subscription_ext.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:bloc/bloc.dart';

class PersonalSubscriptionBloc
    extends Bloc<PersonalSubscriptionEvent, PersonalSubscriptionState> {
  PersonalSubscriptionBloc() : super(PersonalSubscriptionState.loading()) {
    on<PersonalSubscriptionEventInitialize>(_onInitialize);
    on<PersonalSubscriptionEventDidFetch>(_onDidFetch);
  }

  Future<void> _onInitialize(
    PersonalSubscriptionEventInitialize event,
    Emitter<PersonalSubscriptionState> emit,
  ) async {
    await UserEventGetPersonalSubscription().send().fold(
      (subscription) {
        if (!isClosed) {
          add(
            PersonalSubscriptionEvent.didFetch(subscription),
          );
        }
      },
      Log.error,
    );
  }

  Future<void> _onDidFetch(
    PersonalSubscriptionEventDidFetch event,
    Emitter<PersonalSubscriptionState> emit,
  ) async {
    emit(
      PersonalSubscriptionStateLoaded(
        hasVaultSubscription:
            event.subscription.hasActiveVaultWorkspaceSubscription,
      ),
    );
  }
}

sealed class PersonalSubscriptionEvent {
  const PersonalSubscriptionEvent();

  factory PersonalSubscriptionEvent.initialize() =>
      const PersonalSubscriptionEventInitialize();
  factory PersonalSubscriptionEvent.didFetch(
    PersonalSubscriptionInfoPB subscription,
  ) =>
      PersonalSubscriptionEventDidFetch(subscription);
}

class PersonalSubscriptionEventInitialize extends PersonalSubscriptionEvent {
  const PersonalSubscriptionEventInitialize();
}

class PersonalSubscriptionEventDidFetch extends PersonalSubscriptionEvent {
  const PersonalSubscriptionEventDidFetch(this.subscription);

  final PersonalSubscriptionInfoPB subscription;
}

sealed class PersonalSubscriptionState {
  const PersonalSubscriptionState();

  factory PersonalSubscriptionState.loading() =>
      const PersonalSubscriptionStateLoading();
}

class PersonalSubscriptionStateLoading extends PersonalSubscriptionState {
  const PersonalSubscriptionStateLoading();
}

class PersonalSubscriptionStateLoaded extends PersonalSubscriptionState {
  const PersonalSubscriptionStateLoaded({
    required this.hasVaultSubscription,
  });

  final bool hasVaultSubscription;
}
