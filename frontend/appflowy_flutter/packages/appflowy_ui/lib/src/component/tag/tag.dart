import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flutter/widgets.dart';

class AFTag extends StatelessWidget {
  const AFTag({
    super.key,
    required this.text,
    this.textStyle,
    this.color,
    this.padding,
    this.leading,
    this.trailing,
  });

  final String text;
  final TextStyle? textStyle;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Container(
      padding: padding ??
          EdgeInsetsDirectional.only(
            start: theme.spacing.m,
            end: trailing == null ? theme.spacing.m : theme.spacing.xs,
            top: 1.0,
            bottom: 1.0,
          ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(theme.spacing.s),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) leading!,
          Flexible(
            child: Text(
              text,
              style: textStyle ??
                  theme.textStyle.body.standard(
                    color: theme.textColorScheme.primary,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
