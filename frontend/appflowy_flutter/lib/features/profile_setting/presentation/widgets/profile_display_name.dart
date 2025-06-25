import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';

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
    final theme = AppFlowyTheme.of(context), spacing = theme.spacing;
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
        SizedBox(
          width: 300,
          child: AFTextField(
            size: AFTextFieldSize.m,
            controller: controller,
          ),
        ),
      ],
    );
  }
}
