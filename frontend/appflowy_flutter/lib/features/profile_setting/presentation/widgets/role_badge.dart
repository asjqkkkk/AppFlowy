import 'package:appflowy/features/share_tab/data/models/share_role.dart';
import 'package:appflowy/util/theme_extension.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flutter/material.dart';

class ShareRoleBadge extends StatelessWidget {
  const ShareRoleBadge({super.key, required this.role});

  final ShareRole role;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context), spacing = theme.spacing;
    final Widget child = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(theme.spacing.s),
        border: Border.all(color: theme.borderColorScheme.primary),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(spacing.xs, 2, spacing.m, 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildDot(context),
            buildText(context),
          ],
        ),
      ),
    );
    return child;
  }

  Widget buildText(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return Text(
      role.displayName(),
      style: theme.textStyle.body.standard(color: color(context)),
    );
  }

  Widget buildDot(BuildContext context) {
    final theme = AppFlowyTheme.of(context), spacing = theme.spacing;

    return SizedBox.square(
      dimension: 20,
      child: Center(
        child: Container(
          width: spacing.m,
          height: spacing.m,
          decoration: BoxDecoration(
            color: color(context),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Color color(BuildContext context) {
    final theme = AppFlowyTheme.of(context),
        isLight = Theme.of(context).isLightMode;
    switch (role) {
      case ShareRole.owner:
      case ShareRole.member:
        return isLight
            ? theme.badgeColorScheme.color15Thick2
            : theme.badgeColorScheme.color15Thick1;
      case ShareRole.guest:
        return isLight
            ? theme.badgeColorScheme.color3Thick2
            : theme.badgeColorScheme.color3Thick1;
    }
  }
}

extension ShareRoleBadgeStringExtension on ShareRole {
  String displayName() {
    switch (this) {
      case ShareRole.member:
      case ShareRole.owner:
        return '${ShareRole.member.name[0].toUpperCase()}${ShareRole.member.name.substring(1).toLowerCase()}';
      case ShareRole.guest:
        return '${ShareRole.guest.name[0].toUpperCase()}${ShareRole.guest.name.substring(1).toLowerCase()}';
    }
  }
}
