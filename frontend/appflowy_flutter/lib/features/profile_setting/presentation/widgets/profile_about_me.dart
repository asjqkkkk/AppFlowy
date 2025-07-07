import 'package:appflowy/features/profile_setting/logic/profile_setting_bloc.dart';
import 'package:appflowy/features/profile_setting/logic/profile_setting_event.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class ProfileAboutMe extends StatefulWidget {
  const ProfileAboutMe({super.key, required this.aboutMe});

  final String aboutMe;

  @override
  State<ProfileAboutMe> createState() => _ProfileAboutMeState();
}

class _ProfileAboutMeState extends State<ProfileAboutMe> {
  late final TextEditingController controller =
      TextEditingController(text: widget.aboutMe);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context),
        spacing = theme.spacing,
        bloc = context.read<ProfileSettingBloc>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          LocaleKeys.settings_profilePage_aboutMe.tr(),
          style: theme.textStyle.body
              .enhanced(color: theme.textColorScheme.primary),
        ),
        VSpace(spacing.xs),
        SizedBox(
          height: 92,
          width: 400,
          child: AFTextField(
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r"\n"))],
            size: AFTextFieldSize.m,
            controller: controller,
            maxLines: null,
            expands: true,
            maxLength: 190,
            counterText: '',
            textAlignVertical: TextAlignVertical.top,
            keyboardType: TextInputType.multiline,
            onChanged: (v) {
              bloc.add(ProfileSettingUpdateAboutMeEvent(v.trim()));
            },
          ),
        ),
        ValueListenableBuilder(
          valueListenable: controller,
          builder: (_, __, ___) {
            if (controller.text.length < 190) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                VSpace(spacing.xs),
                Text(
                  LocaleKeys.settings_profilePage_limitCharactersReached
                      .tr(args: ['190']),
                  style: theme.textStyle.body
                      .standard(color: theme.textColorScheme.tertiary),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
