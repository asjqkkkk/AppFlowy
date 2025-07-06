import 'package:flowy_infra/theme_extension.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

class PlanProgressIndicator extends StatelessWidget {
  const PlanProgressIndicator({
    super.key,
    required this.label,
    required this.progress,
  });

  final String label;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: _buildProgressBar(context, theme),
        ),
        const HSpace(8),
        FlowyText.medium(
          label,
          fontSize: 11,
          color: AFThemeExtension.of(context).secondaryTextColor,
        ),
        const HSpace(16),
      ],
    );
  }

  Widget _buildProgressBar(BuildContext context, ThemeData theme) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AFThemeExtension.of(context).progressBarBGColor,
        border: Border.all(
          color: const Color(0xFFDDF1F7).withValues(
            alpha: theme.brightness == Brightness.light ? 1 : 0.1,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: progress >= 1
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
