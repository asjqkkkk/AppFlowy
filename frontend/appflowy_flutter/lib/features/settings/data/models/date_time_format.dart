import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:easy_localization/easy_localization.dart';

enum UserDateFormat {
  local,
  us,
  iso,
  friendly,
  dayMonthYear;

  const UserDateFormat();

  factory UserDateFormat.fromInt(int value) {
    return switch (value) {
      0 => local,
      1 => us,
      2 => iso,
      3 => friendly,
      4 => dayMonthYear,
      _ => local,
    };
  }

  factory UserDateFormat.fromUserPB(UserDateFormatPB pb) {
    return switch (pb) {
      UserDateFormatPB.Locally => local,
      UserDateFormatPB.US => us,
      UserDateFormatPB.ISO => iso,
      UserDateFormatPB.Friendly => friendly,
      UserDateFormatPB.DayMonthYear => dayMonthYear,
      _ => local,
    };
  }

  factory UserDateFormat.fromDbPB(DateFormatPB value) {
    return switch (value) {
      DateFormatPB.Local => local,
      DateFormatPB.US => us,
      DateFormatPB.ISO => iso,
      DateFormatPB.Friendly => friendly,
      DateFormatPB.DayMonthYear => dayMonthYear,
      _ => local,
    };
  }

  UserDateFormatPB toUserPB() {
    return switch (this) {
      local => UserDateFormatPB.Locally,
      us => UserDateFormatPB.US,
      iso => UserDateFormatPB.ISO,
      friendly => UserDateFormatPB.Friendly,
      dayMonthYear => UserDateFormatPB.DayMonthYear,
    };
  }

  DateFormatPB toDbPB() {
    return switch (this) {
      local => DateFormatPB.Local,
      us => DateFormatPB.US,
      iso => DateFormatPB.ISO,
      friendly => DateFormatPB.Friendly,
      dayMonthYear => DateFormatPB.DayMonthYear,
    };
  }

  DateFormat getDateFormat() {
    return switch (this) {
      local => DateFormat('MM/dd/y'),
      us => DateFormat('y/MM/dd'),
      iso => DateFormat('y-MM-dd'),
      friendly => DateFormat('MMM dd, y'),
      dayMonthYear => DateFormat('dd/MM/y'),
    };
  }

  String get i18n {
    return switch (this) {
      local => LocaleKeys.settings_workspacePage_dateTime_dateFormat_local.tr(),
      us => LocaleKeys.settings_workspacePage_dateTime_dateFormat_us.tr(),
      iso => LocaleKeys.settings_workspacePage_dateTime_dateFormat_iso.tr(),
      friendly =>
        LocaleKeys.settings_workspacePage_dateTime_dateFormat_friendly.tr(),
      dayMonthYear =>
        LocaleKeys.settings_workspacePage_dateTime_dateFormat_dmy.tr(),
    };
  }
}

enum UserTimeFormat {
  twelveHour,
  twentyFourHour;

  const UserTimeFormat();

  factory UserTimeFormat.fromInt(int value) {
    return switch (value) {
      0 => twelveHour,
      1 => twentyFourHour,
      _ => twelveHour,
    };
  }

  factory UserTimeFormat.fromUserPB(UserTimeFormatPB pb) {
    return switch (pb) {
      UserTimeFormatPB.TwelveHour => twelveHour,
      UserTimeFormatPB.TwentyFourHour => twentyFourHour,
      _ => twelveHour,
    };
  }

  factory UserTimeFormat.fromDbPB(TimeFormatPB value) {
    return switch (value) {
      TimeFormatPB.TwelveHour => twelveHour,
      TimeFormatPB.TwentyFourHour => twentyFourHour,
      _ => twelveHour,
    };
  }

  UserTimeFormatPB toUserPB() {
    return switch (this) {
      twelveHour => UserTimeFormatPB.TwelveHour,
      twentyFourHour => UserTimeFormatPB.TwentyFourHour,
    };
  }

  TimeFormatPB toDbPB() {
    return switch (this) {
      twelveHour => TimeFormatPB.TwelveHour,
      twentyFourHour => TimeFormatPB.TwentyFourHour,
    };
  }

  DateFormat getDateFormat() {
    return switch (this) {
      twelveHour => DateFormat.jm(),
      twentyFourHour => DateFormat.Hm(),
    };
  }

  String get i18n {
    return switch (this) {
      twelveHour => LocaleKeys.settings_appearance_timeFormat_twelveHour.tr(),
      twentyFourHour =>
        LocaleKeys.settings_appearance_timeFormat_twentyFourHour.tr(),
    };
  }
}

DateFormat combineDateTimeFormat(
  UserDateFormat dateFormat,
  UserTimeFormat timeFormat, {
  bool includeTime = false,
}) {
  DateFormat format = dateFormat.getDateFormat();

  if (includeTime) {
    format = switch (timeFormat) {
      UserTimeFormat.twelveHour => format.add_jm(),
      UserTimeFormat.twentyFourHour => format.add_Hm(),
    };
  }

  return format;
}
