import 'package:appflowy/shared/colors.dart';
import 'package:appflowy/workspace/presentation/widgets/toggle/toggle.dart';
import 'package:flowy_infra/theme_extension.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

class ToggleMore extends StatefulWidget {
  const ToggleMore({
    super.key,
    required this.value,
    required this.label,
    this.badgeLabel,
    this.onTap,
  });

  final bool value;
  final String label;
  final String? badgeLabel;
  final Future<void> Function()? onTap;

  @override
  State<ToggleMore> createState() => _ToggleMoreState();
}

class _ToggleMoreState extends State<ToggleMore> {
  late bool toggleValue = widget.value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildToggle(),
        const HSpace(10),
        _buildLabel(context),
        if (widget.badgeLabel != null && widget.badgeLabel!.isNotEmpty)
          _buildBadge(context),
      ],
    );
  }

  Widget _buildToggle() {
    return Toggle(
      value: toggleValue,
      padding: EdgeInsets.zero,
      onChanged: (_) async {
        if (widget.onTap == null || toggleValue) {
          return;
        }

        setState(() => toggleValue = !toggleValue);
        await widget.onTap!();

        if (mounted) {
          setState(() => toggleValue = !toggleValue);
        }
      },
    );
  }

  Widget _buildLabel(BuildContext context) {
    return FlowyText.regular(
      widget.label,
      fontSize: 14,
      color: AFThemeExtension.of(context).strongText,
    );
  }

  Widget _buildBadge(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: SizedBox(
        height: 26,
        child: Badge(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          backgroundColor: context.proSecondaryColor,
          label: FlowyText.semibold(
            widget.badgeLabel!,
            fontSize: 12,
            color: context.proPrimaryColor,
          ),
        ),
      ),
    );
  }
}
