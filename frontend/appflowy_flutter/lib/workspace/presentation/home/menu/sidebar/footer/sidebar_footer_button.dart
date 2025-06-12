import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flutter/material.dart';

// This button style is used in
// - Trash button
// - Template button
class SidebarFooterButton extends StatelessWidget {
  const SidebarFooterButton({
    super.key,
    required this.mainAxisAlignment,
    required this.leftIcon,
    required this.text,
    required this.onTap,
  });

  final MainAxisAlignment mainAxisAlignment;
  final Widget leftIcon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return AFGhostButton.normal(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.m,
        vertical: theme.spacing.s,
      ),
      builder: (context, isHovering, disabled) {
        return Row(
          mainAxisAlignment: mainAxisAlignment,
          spacing: theme.spacing.m,
          children: [
            leftIcon,
            Flexible(
              child: Text(
                text,
                style: theme.textStyle.body.enhanced(
                  color: theme.textColorScheme.secondary,
                ),
                maxLines: 1,
              ),
            ),
          ],
        );
      },
      onTap: onTap,
    );
  }
}
