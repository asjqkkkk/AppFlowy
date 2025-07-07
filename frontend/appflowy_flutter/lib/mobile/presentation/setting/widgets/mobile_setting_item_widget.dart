import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

class MobileSettingItem extends StatelessWidget {
  const MobileSettingItem({
    super.key,
    this.name,
    this.padding = const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    this.trailing,
    this.leadingIcon,
    this.title,
    this.subtitle,
    this.onTap,
  });

  final String? name;
  final EdgeInsets padding;
  final Widget? trailing;
  final Widget? leadingIcon;
  final Widget? subtitle;
  final VoidCallback? onTap;
  final Widget? title;

  @override
  Widget build(BuildContext context) {
    return AFMenuItem(
      title: title ?? _buildDefaultTitle(context, name),
      subtitle: subtitle,
      padding: padding,
      trailing: (context, hovering, disable) => trailing,
      onTap: onTap,
    );
  }

  Widget _buildDefaultTitle(BuildContext context, String? name) {
    final theme = AppFlowyTheme.of(context);
    return Row(
      children: [
        if (leadingIcon != null) ...[
          leadingIcon!,
          const HSpace(8),
        ],
        Expanded(
          child: Text(
            name ?? '',
            style: theme.textStyle.heading4
                .standard(color: theme.textColorScheme.primary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
