import 'package:appflowy/features/color_picker/color_picker.dart';
import 'package:appflowy/features/workspace/workspace.dart';
import 'package:appflowy/shared/flowy_gradient_colors.dart';
import 'package:appflowy/shared/flowy_tint_colors.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PresetColorSelector extends StatefulWidget {
  const PresetColorSelector({
    super.key,
    required this.selectedColor,
    required this.onSelectSolidColor,
    required this.onSelectGradientColor,
  });

  final String? selectedColor;
  final void Function(String color) onSelectSolidColor;
  final void Function(String color) onSelectGradientColor;

  @override
  State<PresetColorSelector> createState() => _PresetColorSelectorState();
}

class _PresetColorSelectorState extends State<PresetColorSelector> {
  late String? currentColor = widget.selectedColor;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    final selectedAFColor = getSelectedColor();

    final userWorkspaceState = context.read<UserWorkspaceBloc>().state;

    final subscriptionPlan = userWorkspaceState.workspaceSubscriptionInfo;
    final isPro = subscriptionPlan != null &&
        subscriptionPlan.plan == SubscriptionPlanPB.Pro;

    return Column(
      spacing: theme.spacing.m,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: getSolidColors()
              .map(
                (color) => ColorTile(
                  color: color,
                  colorType: ColorType.background,
                  isSelected: selectedAFColor == color,
                  onSelect: () {
                    if (selectedAFColor == color) {
                      return;
                    }
                    final savedColor =
                        FlowyTint.fromAFColor(color)?.id ?? FlowyTint.tint1.id;
                    widget.onSelectSolidColor(savedColor);
                    setState(() => currentColor = savedColor);
                  },
                ),
              )
              .toList(),
        ),
        if (isPro)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: getGradientColors()
                .map(
                  (color) => ColorTile(
                    color: color,
                    colorType: ColorType.background,
                    isSelected: selectedAFColor == color,
                    onSelect: () {
                      if (selectedAFColor == color) {
                        return;
                      }
                      final savedColor = FlowyGradient.fromAFColor(color)?.id ??
                          FlowyGradient.gradient1.id;
                      widget.onSelectGradientColor(savedColor);
                      setState(() => currentColor = savedColor);
                    },
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  AFColor? getSelectedColor() {
    final color = currentColor;
    if (color == null) {
      return null;
    }

    final solidColor = FlowyTint.fromId(color);

    if (solidColor != null) {
      return solidColor.toAFColor();
    }

    final hexColor = color.tryToColor();

    if (hexColor != null) {
      return CustomAFColor(color);
    }

    final gradientColor = FlowyGradient.fromId(color);

    if (gradientColor != null) {
      return gradientColor.toAFColor();
    }

    return null;
  }

  List<AFColor> getSolidColors() {
    return [
      FlowyTint.tint1.toAFColor(),
      FlowyTint.tint2.toAFColor(),
      FlowyTint.tint3.toAFColor(),
      FlowyTint.tint4.toAFColor(),
      FlowyTint.tint5.toAFColor(),
      FlowyTint.tint6.toAFColor(),
      FlowyTint.tint7.toAFColor(),
      FlowyTint.tint8.toAFColor(),
      FlowyTint.tint9.toAFColor(),
      FlowyTint.tint10.toAFColor(),
    ];
  }

  List<AFColor> getGradientColors() {
    return [
      FlowyGradient.gradient1.toAFColor(),
      FlowyGradient.gradient2.toAFColor(),
      FlowyGradient.gradient3.toAFColor(),
      FlowyGradient.gradient4.toAFColor(),
      FlowyGradient.gradient5.toAFColor(),
      FlowyGradient.gradient6.toAFColor(),
      FlowyGradient.gradient7.toAFColor(),
      FlowyGradient.gradient8.toAFColor(),
      FlowyGradient.gradient9.toAFColor(),
      FlowyGradient.gradient10.toAFColor(),
    ];
  }
}
