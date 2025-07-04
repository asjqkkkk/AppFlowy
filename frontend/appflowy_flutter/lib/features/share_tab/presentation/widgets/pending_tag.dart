import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flowy_infra_ui/widget/flowy_tooltip.dart';
import 'package:flutter/material.dart';

class PendingTag extends StatelessWidget {
  const PendingTag({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return AFBaseButton(
      backgroundColor: (context, isHovering, disabled) {
        return theme.fillColorScheme.content;
      },
      borderColor: (context, isHovering, disabled, isFocused) {
        return theme.borderColorScheme.primary;
      },
      cursor: SystemMouseCursors.basic,
      padding: EdgeInsets.only(
        left: theme.spacing.m,
        right: theme.spacing.m,
        bottom: 2,
      ),
      borderRadius: theme.spacing.xxl,
      builder: (context, isHovering, disabled) {
        return FlowyTooltip(
          message: 'Invitation not yet accepted',
          child: Text(
            'Pending',
            style: theme.textStyle.caption.standard(
              color: isHovering
                  ? theme.textColorScheme.primary
                  : theme.textColorScheme.secondary,
            ),
          ),
        );
      },
      onTap: () {},
    );
  }
}
