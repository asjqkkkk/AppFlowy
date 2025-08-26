import 'dart:ui';

import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../data/models/date_time_format.dart';
import '../data/models/user_settings.dart';
import '../data/repositories/settings_repository.dart';

class UserAccountSettingBloc
    extends Bloc<UserAccountSettingEvent, UserAccountSettingState> {
  UserAccountSettingBloc({
    required UserProfilePB userProfile,
    required this.repository,
  })  : _userProfile = userProfile,
        super(UserAccountSettingState.initial(userProfile)) {
    on<UserAccountSettingInitialEvent>(_onInitialEvent);
    on<UserAccountSettingDidReceiveEvent>(_onDidReceiveEvent);
    on<UserAccountSettingUpdateEvent>(_onUpdateEvent);
  }

  final UserProfilePB _userProfile;
  final SettingsRepository repository;

  Future<void> _onInitialEvent(
    UserAccountSettingInitialEvent event,
    Emitter<UserAccountSettingState> emit,
  ) async {}

  Future<void> _onDidReceiveEvent(
    UserAccountSettingDidReceiveEvent event,
    Emitter<UserAccountSettingState> emit,
  ) async {
    emit(
      UserAccountSettingState(
        startWeekOnMonday: event.userProfile.startWeekOn == 1,
        dateFormat: UserDateFormat.fromInt(event.userProfile.dateFormat),
        timeFormat: UserTimeFormat.fromInt(event.userProfile.timeFormat),
      ),
    );
  }

  Future<void> _onUpdateEvent(
    UserAccountSettingUpdateEvent event,
    Emitter<UserAccountSettingState> emit,
  ) async {
    emit(
      UserAccountSettingState(
        startWeekOnMonday: event.startWeekOnMonday ?? state.startWeekOnMonday,
        dateFormat: event.dateFormat ?? state.dateFormat,
        timeFormat: event.timeFormat ?? state.timeFormat,
        locale: event.locale ?? state.locale,
      ),
    );

    final result = await repository.updateUserSettings(
      userId: _userProfile.id,
      startWeekOnMonday: event.startWeekOnMonday,
      dateFormat: event.dateFormat?.index,
      timeFormat: event.timeFormat?.index,
      language: event.locale?.toLanguageTag(),
    );

    result.onFailure(Log.error);
  }
}

sealed class UserAccountSettingEvent {
  const UserAccountSettingEvent();

  factory UserAccountSettingEvent.initial() =>
      const UserAccountSettingInitialEvent();

  factory UserAccountSettingEvent.didReceive(UserProfilePB userProfile) =>
      UserAccountSettingDidReceiveEvent(userProfile);

  factory UserAccountSettingEvent.update({
    bool? startWeekOnMonday,
    UserDateFormat? dateFormat,
    UserTimeFormat? timeFormat,
    Locale? locale,
  }) =>
      UserAccountSettingUpdateEvent(
        startWeekOnMonday: startWeekOnMonday,
        dateFormat: dateFormat,
        timeFormat: timeFormat,
        locale: locale,
      );
}

class UserAccountSettingInitialEvent extends UserAccountSettingEvent {
  const UserAccountSettingInitialEvent();
}

class UserAccountSettingDidReceiveEvent extends UserAccountSettingEvent {
  const UserAccountSettingDidReceiveEvent(this.userProfile);

  final UserProfilePB userProfile;
}

class UserAccountSettingUpdateEvent extends UserAccountSettingEvent {
  const UserAccountSettingUpdateEvent({
    this.startWeekOnMonday,
    this.dateFormat,
    this.timeFormat,
    this.locale,
  });

  final bool? startWeekOnMonday;
  final UserDateFormat? dateFormat;
  final UserTimeFormat? timeFormat;
  final Locale? locale;
}

class UserAccountSettingState extends Equatable {
  const UserAccountSettingState({
    this.startWeekOnMonday = false,
    required this.dateFormat,
    required this.timeFormat,
    this.locale = const Locale('en', 'US'),
  });

  factory UserAccountSettingState.initial(UserProfilePB userProfile) {
    final settings = UserSettings.fromUserProfile(userProfile);

    return UserAccountSettingState(
      startWeekOnMonday: settings.startWeekOnMonday,
      dateFormat: settings.dateFormat,
      timeFormat: settings.timeFormat,
      locale: settings.locale,
    );
  }

  final Locale locale;
  final UserDateFormat dateFormat;
  final UserTimeFormat timeFormat;
  final bool startWeekOnMonday;

  @override
  List<Object?> get props => [
        startWeekOnMonday,
        dateFormat,
        timeFormat,
        locale,
      ];
}
