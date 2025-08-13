import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/util/theme_extension.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/widget/flowy_tooltip.dart';
import 'package:flutter/material.dart';

class PersonRoleBadge extends StatelessWidget {
  const PersonRoleBadge({
    super.key,
    required this.person,
    required this.access,
    required this.isDeleted,
  });

  final MentionablePersonPB person;
  final bool access;
  final bool isDeleted;
  MentionablePersonTypePB get role => person.role;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context), spacing = theme.spacing;
    double paddingLeft = spacing.xs;
    if (role == MentionablePersonTypePB.Contact || isDeleted) {
      paddingLeft = spacing.m;
    }
    final noAccess =
        !access && !isDeleted && person.role != MentionablePersonTypePB.Contact;
    Widget child = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(theme.spacing.s),
        border: Border.all(color: theme.borderColorScheme.primary),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(paddingLeft, 2, spacing.m, 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildPrefix(context),
            buildText(context),
          ],
        ),
      ),
    );
    if (noAccess) {
      child = FlowyTooltip(
        message: LocaleKeys.document_mentionMenu_noAccessTooltip.tr(),
        preferBelow: false,
        child: child,
      );
    }
    return child;
  }

  Widget buildPrefix(BuildContext context) {
    if (isDeleted) return const SizedBox.shrink();
    if (role == MentionablePersonTypePB.Contact) return const SizedBox.shrink();
    final theme = AppFlowyTheme.of(context);
    if (!access) {
      return FlowySvg(
        FlowySvgs.person_icon_no_access_m,
        size: Size.square(20),
        color: theme.iconColorScheme.tertiary,
      );
    }
    return buildDot(context);
  }

  Widget buildText(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    if (isDeleted) {
      return Text(
        LocaleKeys.document_mentionMenu_deletedAccount.tr(),
        style: theme.textStyle.body
            .standard(color: theme.textColorScheme.tertiary),
      );
    }
    Color textColor = color(context);
    if (!access) {
      textColor = theme.textColorScheme.tertiary;
    }
    return Text(
      role.displayName(),
      style: theme.textStyle.body.standard(color: textColor),
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
      case MentionablePersonTypePB.WorkspaceMember:
        return isLight
            ? theme.badgeColorScheme.color15Thick2
            : theme.badgeColorScheme.color15Light1;
      case MentionablePersonTypePB.WorkspaceGuest:
        return isLight
            ? theme.badgeColorScheme.color3Thick2
            : theme.badgeColorScheme.color3Light1;
      case MentionablePersonTypePB.Contact:
        return theme.textColorScheme.tertiary;
    }
    return theme.textColorScheme.primary;
  }
}

extension PersonRoleBadgeStringExtension on MentionablePersonTypePB {
  String displayName() {
    switch (this) {
      case MentionablePersonTypePB.WorkspaceMember:
        return LocaleKeys.document_mentionMenu_member.tr();
      case MentionablePersonTypePB.WorkspaceGuest:
        return LocaleKeys.document_mentionMenu_guest.tr();
      case MentionablePersonTypePB.Contact:
        return LocaleKeys.document_mentionMenu_contact.tr();
    }
    return name;
  }
}
