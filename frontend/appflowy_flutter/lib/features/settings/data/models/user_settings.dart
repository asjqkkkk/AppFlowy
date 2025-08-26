import 'dart:ui';

import 'package:appflowy/shared/patterns/common_patterns.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:equatable/equatable.dart';

import 'date_time_format.dart';

class UserSettings extends Equatable {
  const UserSettings({
    required this.locale,
    required this.dateFormat,
    required this.timeFormat,
    required this.startWeekOnMonday,
  });

  factory UserSettings.fromUserProfile(UserProfilePB userProfile) {
    return UserSettings(
      locale:
          parseLocaleString(userProfile.language) ?? const Locale('en', 'US'),
      dateFormat: UserDateFormat.fromInt(userProfile.dateFormat),
      timeFormat: UserTimeFormat.fromInt(userProfile.timeFormat),
      startWeekOnMonday: userProfile.startWeekOn == 1,
    );
  }

  final Locale locale;
  final UserDateFormat dateFormat;
  final UserTimeFormat timeFormat;
  final bool startWeekOnMonday;

  @override
  List<Object?> get props =>
      [locale, dateFormat, timeFormat, startWeekOnMonday];

  static Locale? parseLocaleString(String localeString) {
    final match = localePattern.firstMatch(localeString.trim());
    if (match == null) {
      return null;
    }
    final languageCode = match.group(1)!;
    final countryCode = match.group(2);
    if (countryCode != null && countryCode.isNotEmpty) {
      return Locale(languageCode, countryCode);
    }
    return Locale(languageCode);
  }

  UserSettings copyWith({
    Locale? locale,
    UserDateFormat? dateFormat,
    UserTimeFormat? timeFormat,
    bool? startWeekOnMonday,
  }) {
    return UserSettings(
      locale: locale ?? this.locale,
      dateFormat: dateFormat ?? this.dateFormat,
      timeFormat: timeFormat ?? this.timeFormat,
      startWeekOnMonday: startWeekOnMonday ?? this.startWeekOnMonday,
    );
  }
}
