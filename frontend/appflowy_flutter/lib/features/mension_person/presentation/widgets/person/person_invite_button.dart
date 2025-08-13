import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:universal_platform/universal_platform.dart';

class PersonInviteButton extends StatelessWidget {
  const PersonInviteButton({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return FlowyTooltip(
      preferBelow: false,
      message: LocaleKeys.document_mentionMenu_inviteButtonTooltip.tr(),
      child: AFOutlinedButton.normal(
        onTap: onTap,
        padding:
            EdgeInsets.all(UniversalPlatform.isMobile ? 10 : theme.spacing.s),
        builder: (context, isHovering, disabled) => FlowySvg(
          FlowySvgs.mention_invite_user_m,
          size: Size.square(20),
          color: theme.iconColorScheme.primary,
        ),
      ),
    );
  }
}
