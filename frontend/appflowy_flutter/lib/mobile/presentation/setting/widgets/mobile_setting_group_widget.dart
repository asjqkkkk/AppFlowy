import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flutter/material.dart';

class MobileSettingGroup extends StatelessWidget {
  const MobileSettingGroup({
    required this.groupTitle,
    required this.settingItemList,
    this.showDivider = true,
    super.key,
  });

  final String groupTitle;
  final List<Widget> settingItemList;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context), spacing = theme.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.xl,
            vertical: spacing.s,
          ),
          child: Text(
            groupTitle,
            style: theme.textStyle.heading4.enhanced(
              color: theme.textColorScheme.primary,
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: settingItemList,
        ),
        showDivider
            ? AFDivider(spacing: theme.spacing.m)
            : const SizedBox.shrink(),
      ],
    );
  }
}
