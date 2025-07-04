import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class SharedSectionHeader extends StatelessWidget {
  const SharedSectionHeader({
    super.key,
    required this.onTap,
    this.isExpanded = false,
  });

  final VoidCallback onTap;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return AFBaseButton(
      backgroundColor: (context, isHovering, disabled) {
        final theme = AppFlowyTheme.of(context);
        if (disabled) {
          return Colors.transparent;
        }
        if (isHovering) {
          return theme.fillColorScheme.contentHover;
        }
        return Colors.transparent;
      },
      borderColor: (context, isHovering, disabled, isFocused) {
        return Colors.transparent;
      },
      padding: EdgeInsets.only(
        left: 6,
        top: 6,
        bottom: 6,
      ),
      borderRadius: theme.borderRadius.s,
      onTap: onTap,
      builder: (context, isHovering, disabled) {
        final textColor = theme.textColorScheme.primary;
        return Row(
          children: [
            FlowySvg(
              FlowySvgs.shared_with_me_m,
              color: theme.badgeColorScheme.color13Thick2,
            ),
            SizedBox(width: theme.spacing.s),
            Text(
              LocaleKeys.shareSection_shared.tr(),
              style: AFButtonSize.l.buildTextStyle(context).copyWith(
                    color: textColor,
                  ),
            ),
            SizedBox(width: theme.spacing.xs),
            FlowySvg(
              isExpanded
                  ? FlowySvgs.workspace_drop_down_menu_show_s
                  : FlowySvgs.workspace_drop_down_menu_hide_s,
              color:
                  isHovering ? Theme.of(context).colorScheme.onSurface : null,
            ),
          ],
        );
      },
    );
  }
}
