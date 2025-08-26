import 'dart:async';

import 'package:appflowy/core/config/kv.dart';
import 'package:appflowy/core/config/kv_keys.dart';
import 'package:appflowy/features/settings/settings.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/user/application/user_settings_service.dart';
import 'package:appflowy/util/color_to_hex_string.dart';
import 'package:appflowy/workspace/application/appearance_defaults.dart';
import 'package:appflowy/workspace/application/settings/appearance/base_appearance.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-user/date_time.pbenum.dart';
import 'package:appflowy_backend/protobuf/flowy-user/user_setting.pb.dart';
import 'package:appflowy_editor/appflowy_editor.dart'
    show AppFlowyEditorLocalizations;
import 'package:appflowy_result/appflowy_result.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:equatable/equatable.dart';
import 'package:flowy_infra/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:universal_platform/universal_platform.dart';

/// [AppearanceSettingsCubit] is used to modify the appearance of AppFlowy.
/// It includes:
/// - [AppTheme]
/// - [ThemeMode]
/// - [TextStyle]'s
/// - [Locale]
/// - [UserDateFormatPB]
/// - [UserTimeFormatPB]
///
class AppearanceSettingsCubit extends Cubit<AppearanceSettingsState> {
  AppearanceSettingsCubit({
    required AppearanceSettingsPB appearanceSettings,
    required AppTheme appTheme,
    required UserSettings userSettings,
  })  : _appearanceSettings = appearanceSettings,
        super(
          AppearanceSettingsState.initial(
            appearanceSettings: appearanceSettings,
            appTheme: appTheme,
            userSettings: userSettings,
          ),
        ) {
    readTextScaleFactor();
  }

  final AppearanceSettingsPB _appearanceSettings;

  Future<void> setTextScaleFactor(double textScaleFactor) async {
    // only saved in local storage, this value is not synced across devices
    await getIt<KeyValueStorage>().set(
      KVKeys.textScaleFactor,
      textScaleFactor.toString(),
    );

    // don't allow the text scale factor to be greater than 1.0, it will cause
    // ui issues
    emit(state.copyWith(textScaleFactor: textScaleFactor.clamp(0.7, 1.0)));
  }

  Future<void> readTextScaleFactor() async {
    final textScaleFactor = await getIt<KeyValueStorage>().getWithFormat(
          KVKeys.textScaleFactor,
          (value) => double.parse(value),
        ) ??
        1.0;
    emit(state.copyWith(textScaleFactor: textScaleFactor.clamp(0.7, 1.0)));
  }

  /// Update selected theme in the user's settings and emit an updated state
  /// with the AppTheme named [themeName].
  Future<void> setTheme(String themeName) async {
    _appearanceSettings.theme = themeName;
    unawaited(_saveAppearanceSettings());
    try {
      final theme = await AppTheme.fromName(themeName);
      emit(state.copyWith(appTheme: theme));
    } catch (e) {
      Log.error("Error setting theme: $e");
      if (UniversalPlatform.isMacOS) {
        showToastNotification(
          message:
              LocaleKeys.settings_workspacePage_theme_failedToLoadThemes.tr(),
          type: ToastificationType.error,
        );
      }
    }
  }

  /// Reset the current user selected theme back to the default
  Future<void> resetTheme() =>
      setTheme(DefaultAppearanceSettings.kDefaultThemeName);

  /// Update the theme mode in the user's settings and emit an updated state.
  void setThemeMode(ThemeMode themeMode) {
    _appearanceSettings.themeMode = _themeModeToPB(themeMode);
    _saveAppearanceSettings();
    emit(state.copyWith(themeMode: themeMode));
  }

  /// Resets the current brightness setting
  void resetThemeMode() =>
      setThemeMode(DefaultAppearanceSettings.kDefaultThemeMode);

  /// Toggle the theme mode
  void toggleThemeMode() {
    final currentThemeMode = state.themeMode;
    setThemeMode(
      currentThemeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light,
    );
  }

  void setLayoutDirection(LayoutDirection layoutDirection) {
    _appearanceSettings.layoutDirection = layoutDirection.toLayoutDirectionPB();
    _saveAppearanceSettings();
    emit(state.copyWith(layoutDirection: layoutDirection));
  }

  void setTextDirection(AppFlowyTextDirection textDirection) {
    _appearanceSettings.textDirection = textDirection.toTextDirectionPB();
    _saveAppearanceSettings();
    emit(state.copyWith(textDirection: textDirection));
  }

  void setEnableRTLToolbarItems(bool value) {
    _appearanceSettings.enableRtlToolbarItems = value;
    _saveAppearanceSettings();
    emit(state.copyWith(enableRtlToolbarItems: value));
  }

  /// Update selected font in the user's settings and emit an updated state
  /// with the font name.
  void setFontFamily(String fontFamilyName) {
    _appearanceSettings.font = fontFamilyName;
    _saveAppearanceSettings();
    emit(state.copyWith(font: fontFamilyName));
  }

  /// Resets the current font family for the user preferences
  void resetFontFamily() {
    setFontFamily(DefaultAppearanceSettings.kDefaultFontFamily);
  }

  /// Update document cursor color in the appearance settings and emit an updated state.
  void setDocumentCursorColor(Color color) {
    _appearanceSettings.documentSetting.cursorColor = color.toHexString();
    _saveAppearanceSettings();
  }

  /// Reset document cursor color in the appearance settings
  void resetDocumentCursorColor() {
    _appearanceSettings.documentSetting.cursorColor = '';
    _saveAppearanceSettings();
  }

  /// Update document selection color in the appearance settings and emit an updated state.
  void setDocumentSelectionColor(Color color) {
    _appearanceSettings.documentSetting.selectionColor = color.toHexString();
    _saveAppearanceSettings();
  }

  /// Reset document selection color in the appearance settings
  void resetDocumentSelectionColor() {
    _appearanceSettings.documentSetting.selectionColor = '';
    _saveAppearanceSettings();
  }

  /// Updates the current locale and notify the listeners the locale was
  /// changed. Fallback to [en-US] locale if [newLocale] is not supported.
  void setLocale(BuildContext context, Locale newLocale) async {
    if (!context.supportedLocales.contains(newLocale)) {
      // Log.warn("Unsupported locale: $newLocale, Fallback to locale: en-US");
      newLocale = const Locale('en', 'US');
    }

    if (newLocale == state.locale) {
      return;
    }

    await context.setLocale(newLocale).catchError((e) {
      Log.warn('Catch error in setLocale: $e');
    });
    await AppFlowyEditorLocalizations.load(newLocale);

    emit(
      state.copyWith(locale: newLocale),
    );
    _appearanceSettings.locale.languageCode = newLocale.languageCode;
    _appearanceSettings.locale.countryCode = newLocale.countryCode ?? "";
    await _saveAppearanceSettings();
  }

  /// Sets sidebar menu preferences
  void setMenuPreferences({
    bool? isCollapsed,
    double? offset,
  }) {
    _appearanceSettings.isMenuCollapsed =
        isCollapsed ?? _appearanceSettings.isMenuCollapsed;
    _appearanceSettings.menuOffset = offset ?? _appearanceSettings.menuOffset;
    _saveAppearanceSettings();
  }

  /// Called when the application launches.
  /// Uses the device locale when the application is opened for the first time.
  void readLocaleWhenAppLaunch(BuildContext context) {
    if (_appearanceSettings.resetToDefault) {
      _appearanceSettings.resetToDefault = false;
      _saveAppearanceSettings();
      setLocale(context, context.deviceLocale);
      return;
    }

    setLocale(context, state.locale);
  }

  void setDateTimeFormat({
    UserDateFormat? dateFormat,
    UserTimeFormat? timeFormat,
    bool? startWeekOnMonday,
  }) async {
    emit(
      state.copyWith(
        dateFormat: dateFormat,
        timeFormat: timeFormat,
        startWeekOnMonday: startWeekOnMonday,
      ),
    );
  }

  Future<void> _saveAppearanceSettings() async {
    await UserSettingsBackendService()
        .setAppearanceSetting(_appearanceSettings)
        .onFailure(Log.error);
  }
}

ThemeMode _themeModeFromPB(ThemeModePB themeModePB) {
  return switch (themeModePB) {
    ThemeModePB.Light => ThemeMode.light,
    ThemeModePB.Dark => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

ThemeModePB _themeModeToPB(ThemeMode themeMode) {
  return switch (themeMode) {
    ThemeMode.light => ThemeModePB.Light,
    ThemeMode.dark => ThemeModePB.Dark,
    ThemeMode.system => ThemeModePB.System,
  };
}

enum LayoutDirection {
  ltrLayout,
  rtlLayout;

  static LayoutDirection fromLayoutDirectionPB(
    LayoutDirectionPB layoutDirectionPB,
  ) =>
      layoutDirectionPB == LayoutDirectionPB.RTLLayout
          ? LayoutDirection.rtlLayout
          : LayoutDirection.ltrLayout;

  LayoutDirectionPB toLayoutDirectionPB() => this == LayoutDirection.rtlLayout
      ? LayoutDirectionPB.RTLLayout
      : LayoutDirectionPB.LTRLayout;
}

enum AppFlowyTextDirection {
  ltr,
  rtl,
  auto;

  static AppFlowyTextDirection fromTextDirectionPB(
    TextDirectionPB? textDirectionPB,
  ) {
    return switch (textDirectionPB) {
      TextDirectionPB.LTR => AppFlowyTextDirection.ltr,
      TextDirectionPB.RTL => AppFlowyTextDirection.rtl,
      TextDirectionPB.AUTO => AppFlowyTextDirection.auto,
      _ => AppFlowyTextDirection.ltr
    };
  }

  TextDirectionPB toTextDirectionPB() {
    return switch (this) {
      AppFlowyTextDirection.ltr => TextDirectionPB.LTR,
      AppFlowyTextDirection.rtl => TextDirectionPB.RTL,
      AppFlowyTextDirection.auto => TextDirectionPB.AUTO
    };
  }
}

class AppearanceSettingsState extends Equatable {
  const AppearanceSettingsState({
    required this.appTheme,
    required this.themeMode,
    required this.font,
    required this.layoutDirection,
    required this.textDirection,
    required this.enableRtlToolbarItems,
    required this.locale,
    required this.isMenuCollapsed,
    required this.menuOffset,
    required this.dateFormat,
    required this.timeFormat,
    required this.timezoneId,
    required this.startWeekOnMonday,
    required this.textScaleFactor,
  });

  factory AppearanceSettingsState.initial({
    required AppearanceSettingsPB appearanceSettings,
    required AppTheme appTheme,
    required UserSettings userSettings,
  }) {
    return AppearanceSettingsState(
      appTheme: appTheme,
      font: appearanceSettings.font,
      layoutDirection: LayoutDirection.fromLayoutDirectionPB(
        appearanceSettings.layoutDirection,
      ),
      textDirection: AppFlowyTextDirection.fromTextDirectionPB(
        appearanceSettings.textDirection,
      ),
      enableRtlToolbarItems: appearanceSettings.enableRtlToolbarItems,
      themeMode: _themeModeFromPB(appearanceSettings.themeMode),
      locale: userSettings.locale,
      isMenuCollapsed: appearanceSettings.isMenuCollapsed,
      menuOffset: appearanceSettings.menuOffset,
      dateFormat: userSettings.dateFormat,
      timeFormat: userSettings.timeFormat,
      timezoneId: "",
      startWeekOnMonday: userSettings.startWeekOnMonday,
      textScaleFactor: 1.0,
    );
  }

  final AppTheme appTheme;
  final ThemeMode themeMode;
  final String font;
  final LayoutDirection layoutDirection;
  final AppFlowyTextDirection textDirection;
  final bool enableRtlToolbarItems;
  final Locale locale;
  final bool isMenuCollapsed;
  final double menuOffset;
  final UserDateFormat dateFormat;
  final UserTimeFormat timeFormat;
  final String timezoneId;
  final bool startWeekOnMonday;
  final double textScaleFactor;

  AppearanceSettingsState copyWith({
    AppTheme? appTheme,
    ThemeMode? themeMode,
    String? font,
    LayoutDirection? layoutDirection,
    AppFlowyTextDirection? textDirection,
    bool? enableRtlToolbarItems,
    Locale? locale,
    bool? isMenuCollapsed,
    double? menuOffset,
    UserDateFormat? dateFormat,
    UserTimeFormat? timeFormat,
    String? timezoneId,
    bool? startWeekOnMonday,
    double? textScaleFactor,
  }) {
    return AppearanceSettingsState(
      appTheme: appTheme ?? this.appTheme,
      themeMode: themeMode ?? this.themeMode,
      font: font ?? this.font,
      layoutDirection: layoutDirection ?? this.layoutDirection,
      textDirection: textDirection ?? this.textDirection,
      enableRtlToolbarItems:
          enableRtlToolbarItems ?? this.enableRtlToolbarItems,
      locale: locale ?? this.locale,
      isMenuCollapsed: isMenuCollapsed ?? this.isMenuCollapsed,
      menuOffset: menuOffset ?? this.menuOffset,
      dateFormat: dateFormat ?? this.dateFormat,
      timeFormat: timeFormat ?? this.timeFormat,
      timezoneId: timezoneId ?? this.timezoneId,
      startWeekOnMonday: startWeekOnMonday ?? this.startWeekOnMonday,
      textScaleFactor: textScaleFactor ?? this.textScaleFactor,
    );
  }

  ThemeData get lightTheme => _getThemeData(Brightness.light);

  ThemeData get darkTheme => _getThemeData(Brightness.dark);

  ThemeData _getThemeData(Brightness brightness) {
    return getIt<BaseAppearance>().getThemeData(
      appTheme,
      brightness,
      font,
      builtInCodeFontFamily,
    );
  }

  @override
  List<Object?> get props => [
        appTheme,
        themeMode,
        font,
        layoutDirection,
        textDirection,
        enableRtlToolbarItems,
        locale,
        isMenuCollapsed,
        menuOffset,
        dateFormat,
        timeFormat,
        timezoneId,
        startWeekOnMonday,
        textScaleFactor,
      ];
}
