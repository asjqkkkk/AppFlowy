import 'package:appflowy/features/settings/settings.dart';
import 'package:appflowy/user/application/user_settings_service.dart';
import 'package:appflowy/workspace/application/settings/appearance/appearance_cubit.dart';
import 'package:appflowy/workspace/application/settings/appearance/base_appearance.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flowy_infra/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../util.dart';

void main() {
  // ignore: unused_local_variable
  late AppFlowyUnitTest context;
  setUpAll(() async {
    context = await AppFlowyUnitTest.ensureInitialized();
  });

  group('$AppearanceSettingsCubit', () {
    late AppearanceSettingsPB appearanceSetting;

    setUp(() async {
      appearanceSetting =
          await UserSettingsBackendService().getAppearanceSetting();
      await blocResponseFuture();
    });

    blocTest<AppearanceSettingsCubit, AppearanceSettingsState>(
      'default theme',
      build: () => AppearanceSettingsCubit(
        appearanceSettings: appearanceSetting,
        appTheme: AppTheme.fallback,
        userSettings: UserSettings(
          locale: Locale(
            appearanceSetting.locale.languageCode,
            appearanceSetting.locale.countryCode,
          ),
          startWeekOnMonday: false,
          dateFormat: UserDateFormat.local,
          timeFormat: UserTimeFormat.twelveHour,
        ),
      ),
      verify: (bloc) {
        expect(bloc.state.font, defaultFontFamily);
        expect(bloc.state.themeMode, ThemeMode.system);
      },
    );

    blocTest<AppearanceSettingsCubit, AppearanceSettingsState>(
      'initial state uses fallback theme',
      build: () => AppearanceSettingsCubit(
        appearanceSettings: appearanceSetting,
        appTheme: AppTheme.fallback,
        userSettings: UserSettings(
          locale: Locale(
            appearanceSetting.locale.languageCode,
            appearanceSetting.locale.countryCode,
          ),
          startWeekOnMonday: false,
          dateFormat: UserDateFormat.local,
          timeFormat: UserTimeFormat.twelveHour,
        ),
      ),
      verify: (bloc) {
        expect(bloc.state.appTheme.themeName, AppTheme.fallback.themeName);
      },
    );
  });
}
