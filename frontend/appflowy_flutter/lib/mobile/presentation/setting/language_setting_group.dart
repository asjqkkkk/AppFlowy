import 'package:appflowy/features/settings/settings.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/bottom_sheet.dart';
import 'package:appflowy/mobile/presentation/setting/language/language_picker_screen.dart';
import 'package:appflowy/mobile/presentation/setting/widgets/mobile_setting_trailing.dart';
import 'package:appflowy/mobile/presentation/widgets/flowy_option_tile.dart';
import 'package:appflowy/workspace/application/settings/appearance/appearance_cubit.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'setting.dart';

class LanguageSettingGroup extends StatefulWidget {
  const LanguageSettingGroup({
    super.key,
  });

  @override
  State<LanguageSettingGroup> createState() => _LanguageSettingGroupState();
}

class _LanguageSettingGroupState extends State<LanguageSettingGroup> {
  @override
  Widget build(BuildContext context) {
    return BlocSelector<AppearanceSettingsCubit, AppearanceSettingsState,
        Locale>(
      selector: (state) {
        return state.locale;
      },
      builder: (context, locale) {
        return MobileSettingGroup(
          groupTitle: LocaleKeys.settings_menu_language.tr(),
          settingItemList: [
            MobileSettingItem(
              name: LocaleKeys.settings_menu_language.tr(),
              trailing: MobileSettingTrailing(
                text: languageFromLocale(locale),
              ),
              onTap: () async {
                final newLocale =
                    await context.push<Locale>(LanguagePickerScreen.routeName);
                if (newLocale != null && newLocale != locale) {
                  if (context.mounted) {
                    context
                        .read<AppearanceSettingsCubit>()
                        .setLocale(context, newLocale);
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
}

class LanguageAndTimeDateSettingGroup extends StatelessWidget {
  const LanguageAndTimeDateSettingGroup({
    super.key,
    required this.userProfile,
  });

  final UserProfilePB userProfile;

  @override
  Widget build(BuildContext context) {
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
            children: [
              MobileSettingGroup(
                groupTitle:
                    LocaleKeys.settings_accountPage_dateAndTime_title.tr(),
                settingItemList: [
                  _DateFormatSection(
                    dateFormat: state.dateFormat,
                    onSelect: (value) {
                      appearanceBloc.setDateTimeFormat(
                        dateFormat: value,
                      );
                      userSettingBloc.add(
                        UserAccountSettingEvent.update(
                          dateFormat: value,
                        ),
                      );
                    },
                  ),
                  _TimeFormatSection(
                    timeFormat: state.timeFormat,
                    onSelect: (value) {
                      appearanceBloc.setDateTimeFormat(
                        timeFormat: value,
                      );
                      userSettingBloc.add(
                        UserAccountSettingEvent.update(
                          timeFormat: value,
                        ),
                      );
                    },
                  ),
                  _StartWeekOnMondaySection(
                    startWeekOnMonday: state.startWeekOnMonday,
                    onSelect: (value) {
                      appearanceBloc.setDateTimeFormat(
                        startWeekOnMonday: value,
                      );
                      userSettingBloc.add(
                        UserAccountSettingEvent.update(
                          startWeekOnMonday: value,
                        ),
                      );
                    },
                  ),
                ],
              ),
              MobileSettingGroup(
                groupTitle: LocaleKeys.settings_menu_language.tr(),
                settingItemList: [
                  MobileSettingItem(
                    name: LocaleKeys.settings_menu_language.tr(),
                    trailing: MobileSettingTrailing(
                      text: languageFromLocale(state.locale),
                    ),
                    onTap: () async {
                      final newLocale = await context
                          .push<Locale>(LanguagePickerScreen.routeName);

                      if (newLocale != null &&
                          newLocale != state.locale &&
                          context.mounted) {
                        appearanceBloc.setLocale(context, newLocale);
                        userSettingBloc.add(
                          UserAccountSettingEvent.update(locale: newLocale),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DateFormatSection extends StatelessWidget {
  const _DateFormatSection({
    required this.dateFormat,
    required this.onSelect,
  });

  final UserDateFormat dateFormat;
  final void Function(UserDateFormat) onSelect;

  @override
  Widget build(BuildContext context) {
    return MobileSettingItem(
      name: LocaleKeys.settings_accountPage_dateAndTime_dateFormat.tr(),
      trailing: MobileSettingTrailing(
        text: dateFormat.i18n,
      ),
      onTap: () async {
        final newDateFormat = await showBottomSheet(context);

        if (newDateFormat != null && newDateFormat != dateFormat) {
          onSelect(newDateFormat);
        }
      },
    );
  }

  Future<UserDateFormat?> showBottomSheet(BuildContext context) {
    return showMobileBottomSheet(
      context,
      showDragHandle: true,
      showHeader: true,
      title: LocaleKeys.settings_accountPage_dateAndTime_dateFormat.tr(),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: UserDateFormat.values
              .map(
                (format) => FlowyOptionTile.checkbox(
                  text: format.i18n,
                  isSelected: format == dateFormat,
                  onTap: () => Navigator.of(context).pop(format),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _TimeFormatSection extends StatelessWidget {
  const _TimeFormatSection({
    required this.timeFormat,
    required this.onSelect,
  });

  final UserTimeFormat timeFormat;
  final void Function(UserTimeFormat) onSelect;

  @override
  Widget build(BuildContext context) {
    return MobileSettingItem(
      name: LocaleKeys.settings_accountPage_dateAndTime_timeFormat.tr(),
      trailing: MobileSettingTrailing(
        text: timeFormat.i18n,
      ),
      onTap: () async {
        final newTimeFormat = await showBottomSheet(context);

        if (newTimeFormat != null && newTimeFormat != timeFormat) {
          onSelect(newTimeFormat);
        }
      },
    );
  }

  Future<UserTimeFormat?> showBottomSheet(BuildContext context) {
    return showMobileBottomSheet(
      context,
      showDragHandle: true,
      showHeader: true,
      title: LocaleKeys.settings_accountPage_dateAndTime_timeFormat.tr(),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: UserTimeFormat.values
              .map(
                (format) => FlowyOptionTile.checkbox(
                  text: format.i18n,
                  isSelected: format == timeFormat,
                  onTap: () => Navigator.of(context).pop(format),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _StartWeekOnMondaySection extends StatelessWidget {
  const _StartWeekOnMondaySection({
    required this.startWeekOnMonday,
    required this.onSelect,
  });

  final bool startWeekOnMonday;
  final void Function(bool) onSelect;

  @override
  Widget build(BuildContext context) {
    final languageTag = context.locale.toLanguageTag();

    return MobileSettingItem(
      name: LocaleKeys.settings_accountPage_dateAndTime_startWeekOn.tr(),
      trailing: MobileSettingTrailing(
        text: getName(startWeekOnMonday, languageTag),
      ),
      onTap: () async {
        final newStartWeekOnMonday =
            await showBottomSheet(context, languageTag);

        if (newStartWeekOnMonday != null &&
            newStartWeekOnMonday != startWeekOnMonday) {
          onSelect(newStartWeekOnMonday);
        }
      },
    );
  }

  String getName(bool startWeekOnMonday, String languageTag) {
    final symbols = DateFormat.EEEE(languageTag).dateSymbols;

    return startWeekOnMonday ? symbols.WEEKDAYS[1] : symbols.WEEKDAYS[0];
  }

  Future<bool?> showBottomSheet(BuildContext context, String languageTag) {
    return showMobileBottomSheet(
      context,
      showDragHandle: true,
      showHeader: true,
      title: LocaleKeys.settings_accountPage_dateAndTime_dateFormat.tr(),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlowyOptionTile.checkbox(
              text: getName(false, languageTag),
              isSelected: !startWeekOnMonday,
              onTap: () => Navigator.of(context).pop(false),
            ),
            FlowyOptionTile.checkbox(
              text: getName(true, languageTag),
              isSelected: startWeekOnMonday,
              onTap: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
  }
}
