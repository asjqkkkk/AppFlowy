import 'dart:async';

import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'personal_subscription_bloc.freezed.dart';

class PersonalSubscriptionBloc
    extends Bloc<PersonalSubscriptionEvent, PersonalSubscriptionState> {
  PersonalSubscriptionBloc() : super(PersonalSubscriptionState.initial()) {
    on<PersonalSubscriptionEventInitialize>(_onInitialize);
    on<PersonalSubscriptionEventFetch>(_onFetch);
    on<PersonalSubscriptionEventDidFetch>(_onDidFetch);
  }

  Future<void> _onInitialize(
    PersonalSubscriptionEventInitialize event,
    Emitter<PersonalSubscriptionState> emit,
  ) async {
    add(const PersonalSubscriptionEvent.fetch());
  }

  Future<void> _onFetch(
    PersonalSubscriptionEventFetch event,
    Emitter<PersonalSubscriptionState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    unawaited(
      UserEventGetPersonalSubscription().send().then(
        (result) {
          result.fold(
            (subscription) {
              if (!isClosed) {
                add(
                  PersonalSubscriptionEvent.didFetch(
                    false,
                    subscription,
                  ),
                );
              }
            },
            (error) {
              if (!isClosed) {
                add(
                  PersonalSubscriptionEvent.didFetch(false, null),
                );
              }
            },
          );
        },
      ),
    );
  }

  Future<void> _onDidFetch(
    PersonalSubscriptionEventDidFetch event,
    Emitter<PersonalSubscriptionState> emit,
  ) async {
    emit(
      state.copyWith(
        subscription: event.subscription,
        isLoading: event.isLoading,
      ),
    );
  }
}

@freezed
class PersonalSubscriptionEvent with _$PersonalSubscriptionEvent {
  const factory PersonalSubscriptionEvent.initialize() =
      PersonalSubscriptionEventInitialize;
  const factory PersonalSubscriptionEvent.fetch() =
      PersonalSubscriptionEventFetch;
  const factory PersonalSubscriptionEvent.didFetch(
    bool isLoading,
    PersonalSubscriptionInfoPB? subscription,
  ) = PersonalSubscriptionEventDidFetch;
}

@freezed
class PersonalSubscriptionState with _$PersonalSubscriptionState {
  const factory PersonalSubscriptionState({
    PersonalSubscriptionInfoPB? subscription,
    @Default(false) bool isLoading,
  }) = _PersonalSubscriptionState;

  factory PersonalSubscriptionState.initial() =>
      const PersonalSubscriptionState();
}
