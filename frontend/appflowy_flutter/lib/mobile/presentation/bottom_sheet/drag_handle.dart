import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flutter/material.dart';

class DragHandle extends StatelessWidget {
  const DragHandle({
    super.key,
    this.margin,
  });

  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Container(
      height: 4.0,
      width: 36.0,
      margin: margin ?? EdgeInsets.symmetric(vertical: theme.spacing.s),
      decoration: BoxDecoration(
        color: theme.iconColorScheme.quaternary,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
