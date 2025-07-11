import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/workspace/presentation/settings/pages/settings_plan_view/widgets/plan_progress_indicator.dart';
import 'package:flowy_infra/theme_extension.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

class UsageBox extends StatelessWidget {
  const UsageBox({
    super.key,
    required this.title,
    required this.label,
    required this.value,
    required this.unlimitedLabel,
    this.unlimited = false,
  });

  final String title;
  final String label;
  final double value;
  final String unlimitedLabel;
  final bool unlimited;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FlowyText.medium(
          title,
          fontSize: 11,
          color: AFThemeExtension.of(context).secondaryTextColor,
        ),
        if (unlimited) ...[
          _buildUnlimitedBadge(),
        ] else ...[
          const VSpace(4),
          PlanProgressIndicator(label: label, progress: value),
        ],
      ],
    );
  }

  Widget _buildUnlimitedBadge() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FlowySvg(
            FlowySvgs.check_circle_outlined_s,
            color: Color(0xFF9C00FB),
          ),
          const HSpace(4),
          FlowyText(
            unlimitedLabel,
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
        ],
      ),
    );
  }
}
