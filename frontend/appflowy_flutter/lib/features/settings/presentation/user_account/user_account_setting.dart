import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/workspace/application/settings/appearance/appearance_cubit.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:equatable/equatable.dart';
import 'package:flowy_infra/language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/date_time_format.dart';
import '../../data/repositories/rust_settings_repository_impl.dart';
import '../../logic/user_account_setting_bloc.dart';

class UserAccountSetting extends StatelessWidget {
  const UserAccountSetting({
    super.key,
    required this.userProfile,
  });

  final UserProfilePB userProfile;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return BlocProvider(
      create: (context) => UserAccountSettingBloc(
        repository: RustSettingsRepositoryImpl(),
        userProfile: userProfile,
      ),
      child: BlocBuilder<UserAccountSettingBloc, UserAccountSettingState>(
        builder: (context, state) {
          final appearanceBloc = context.read<AppearanceSettingsCubit>();
          final userSettingBloc = context.read<UserAccountSettingBloc>();

          return Column(
            spacing: theme.spacing.xxl,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateAndTimeFormatHeading(
                theme: theme,
              ),
              Column(
                spacing: theme.spacing.m,
                children: [
                  _DateFormatSection(
                    theme: theme,
                    dateFormat: state.dateFormat,
                    onSelect: (dateFormat) {
                      appearanceBloc.setDateTimeFormat(dateFormat: dateFormat);
                      userSettingBloc.add(
                        UserAccountSettingEvent.update(dateFormat: dateFormat),
                      );
                    },
                  ),
                  _TimeFormatSection(
                    theme: theme,
                    timeFormat: state.timeFormat,
                    onSelect: (timeFormat) {
                      appearanceBloc.setDateTimeFormat(timeFormat: timeFormat);
                      userSettingBloc.add(
                        UserAccountSettingEvent.update(timeFormat: timeFormat),
                      );
                    },
                  ),
                  _StartWeekOnSection(
                    theme: theme,
                    startWeekOnMonday: state.startWeekOnMonday,
                    onSelect: (startWeekOnMonday) {
                      appearanceBloc.setDateTimeFormat(
                        startWeekOnMonday: startWeekOnMonday,
                      );
                      userSettingBloc.add(
                        UserAccountSettingEvent.update(
                          startWeekOnMonday: startWeekOnMonday,
                        ),
                      );
                    },
                  ),
                ],
              ),
              AFDivider(),
              LanguageSection(
                theme: theme,
                locale: state.locale,
                onSelect: (locale) {
                  appearanceBloc.setLocale(context, locale);
                  userSettingBloc.add(
                    UserAccountSettingEvent.update(locale: locale),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DateAndTimeFormatHeading extends StatelessWidget {
  const _DateAndTimeFormatHeading({
    required this.theme,
  });

  final AppFlowyThemeData theme;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final state = context.read<UserAccountSettingBloc>().state;
    final combined = combineDateTimeFormat(
      state.dateFormat,
      state.timeFormat,
      includeTime: true,
    );
    final previewText = "${combined.format(now)} (${now.timeZoneName})";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: theme.spacing.xs,
      children: [
        Text(
          LocaleKeys.settings_accountPage_dateAndTime_title.tr(),
          style: theme.textStyle.body.enhanced(
            color: theme.textColorScheme.primary,
          ),
        ),
        Text(
          previewText,
          style: theme.textStyle.caption.standard(
            color: theme.textColorScheme.secondary,
          ),
        ),
      ],
    );
  }
}

class _DateFormatSection extends StatelessWidget {
  const _DateFormatSection({
    required this.theme,
    required this.dateFormat,
    required this.onSelect,
  });

  final AppFlowyThemeData theme;
  final UserDateFormat dateFormat;
  final void Function(UserDateFormat) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: theme.spacing.xs,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocaleKeys.settings_accountPage_dateAndTime_dateFormat.tr(),
          style: theme.textStyle.caption.enhanced(
            color: theme.textColorScheme.secondary,
          ),
        ),
        SizedBox(
          width: 400,
          child: AFDropDownMenu<_DateFormatDropDownItem>(
            isRequired: true,
            isClearEnabled: false,
            items: [
              _DateFormatDropDownItem(UserDateFormat.local),
              _DateFormatDropDownItem(UserDateFormat.us),
              _DateFormatDropDownItem(UserDateFormat.iso),
              _DateFormatDropDownItem(UserDateFormat.friendly),
              _DateFormatDropDownItem(UserDateFormat.dayMonthYear),
            ],
            selectedItems: [_DateFormatDropDownItem(dateFormat)],
            onSelect: (value) {
              if (value != null) {
                onSelect(value.format);
              }
            },
          ),
        ),
      ],
    );
  }
}

class _TimeFormatSection extends StatelessWidget {
  const _TimeFormatSection({
    required this.theme,
    required this.timeFormat,
    required this.onSelect,
  });

  final AppFlowyThemeData theme;
  final UserTimeFormat timeFormat;
  final void Function(UserTimeFormat) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: theme.spacing.xs,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocaleKeys.settings_accountPage_dateAndTime_timeFormat.tr(),
          style: theme.textStyle.caption.enhanced(
            color: theme.textColorScheme.secondary,
          ),
        ),
        SizedBox(
          width: 400,
          child: AFDropDownMenu(
            isRequired: true,
            isClearEnabled: false,
            items: [
              _TimeFormatDropDownItem(UserTimeFormat.twelveHour),
              _TimeFormatDropDownItem(UserTimeFormat.twentyFourHour),
            ],
            selectedItems: [_TimeFormatDropDownItem(timeFormat)],
            onSelect: (value) {
              if (value != null) {
                onSelect(value.format);
              }
            },
          ),
        ),
      ],
    );
  }
}

class _StartWeekOnSection extends StatelessWidget {
  const _StartWeekOnSection({
    required this.theme,
    required this.startWeekOnMonday,
    required this.onSelect,
  });

  final AppFlowyThemeData theme;
  final bool startWeekOnMonday;
  final void Function(bool) onSelect;

  @override
  Widget build(BuildContext context) {
    final languageTag = context.locale.toLanguageTag();

    return Column(
      spacing: theme.spacing.xs,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocaleKeys.settings_accountPage_dateAndTime_startWeekOn.tr(),
          style: theme.textStyle.caption.enhanced(
            color: theme.textColorScheme.secondary,
          ),
        ),
        SizedBox(
          width: 400,
          child: AFDropDownMenu(
            isRequired: true,
            isClearEnabled: false,
            items: [
              _StartWeekOnDropDownItem(false, languageTag),
              _StartWeekOnDropDownItem(true, languageTag),
            ],
            selectedItems: [
              _StartWeekOnDropDownItem(startWeekOnMonday, languageTag),
            ],
            onSelect: (value) {
              if (value != null) {
                onSelect(value.startWeekOnMonday);
              }
            },
          ),
        ),
      ],
    );
  }
}

class LanguageSection extends StatelessWidget {
  const LanguageSection({
    super.key,
    required this.theme,
    required this.locale,
    required this.onSelect,
  });

  final AppFlowyThemeData theme;
  final Locale locale;
  final void Function(Locale) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: theme.spacing.xs,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocaleKeys.settings_workspacePage_language_title.tr(),
          style: theme.textStyle.body.enhanced(
            color: theme.textColorScheme.primary,
          ),
        ),
        SizedBox(
          width: 400,
          child: AFDropDownMenu(
            isRequired: true,
            isClearEnabled: false,
            items: _getSupportedLocales(context),
            selectedItems: [_LanguageDropDownItem(locale)],
            onSelect: (value) {
              if (value != null) {
                onSelect(value.locale);
              }
            },
          ),
        ),
      ],
    );
  }

  List<_LanguageDropDownItem> _getSupportedLocales(BuildContext context) {
    return EasyLocalization.of(context)!
        .supportedLocales
        .map((locale) => _LanguageDropDownItem(locale))
        .toList();
  }
}

class _DateFormatDropDownItem with AFDropDownMenuMixin, EquatableMixin {
  _DateFormatDropDownItem(this.format);

  final UserDateFormat format;

  @override
  List<Object?> get props => [format];

  @override
  String get label => format.i18n;
}

class _TimeFormatDropDownItem with AFDropDownMenuMixin, EquatableMixin {
  _TimeFormatDropDownItem(this.format);

  final UserTimeFormat format;

  @override
  List<Object?> get props => [format];

  @override
  String get label => format.i18n;
}

class _StartWeekOnDropDownItem with AFDropDownMenuMixin, EquatableMixin {
  _StartWeekOnDropDownItem(this.startWeekOnMonday, this.languageTag);

  final bool startWeekOnMonday;
  final String languageTag;

  @override
  List<Object?> get props => [startWeekOnMonday];

  @override
  String get label {
    final symbols = DateFormat.EEEE(languageTag).dateSymbols;

    return startWeekOnMonday ? symbols.WEEKDAYS[1] : symbols.WEEKDAYS[0];
  }
}

class _LanguageDropDownItem with AFDropDownMenuMixin, EquatableMixin {
  _LanguageDropDownItem(this.locale);

  final Locale locale;

  @override
  List<Object?> get props => [locale];

  @override
  String get label => languageFromLocale(locale);
}
