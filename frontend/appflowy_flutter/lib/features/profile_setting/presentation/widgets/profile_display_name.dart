import 'package:appflowy/features/profile_setting/logic/profile_setting_bloc.dart';
import 'package:appflowy/features/profile_setting/logic/profile_setting_event.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ProfileDisplayName extends StatefulWidget {
  const ProfileDisplayName({
    super.key,
    required this.name,
  });

  final String name;

  @override
  State<ProfileDisplayName> createState() => _ProfileDisplayNameState();
}

class _ProfileDisplayNameState extends State<ProfileDisplayName> {
  late final TextEditingController controller =
      TextEditingController(text: widget.name);

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
          LocaleKeys.settings_profilePage_displayName.tr(),
          style: theme.textStyle.body
              .enhanced(color: theme.textColorScheme.primary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        VSpace(spacing.xs),
        Row(
          children: [
            Flexible(
              child: SizedBox(
                width: 300,
                child: AFTextField(
                  size: AFTextFieldSize.m,
                  controller: controller,
                  counterText: '',
                  maxLength: 72,
                  onChanged: (v) {
                    if (v.trim().isNotEmpty) {
                      bloc.add(ProfileSettingUpdateNameEvent(v.trim()));
                    }
                  },
                ),
              ),
            ),
            ValueListenableBuilder(
              valueListenable: controller,
              builder: (_, __, ___) {
                final text = controller.text.trim();
                if (text.length < 72) return const SizedBox.shrink();
                return Padding(
                  padding: EdgeInsets.only(left: spacing.m),
                  child: Text(
                    '72 / 72',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: theme.textStyle.body
                        .standard(color: theme.textColorScheme.tertiary),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}
