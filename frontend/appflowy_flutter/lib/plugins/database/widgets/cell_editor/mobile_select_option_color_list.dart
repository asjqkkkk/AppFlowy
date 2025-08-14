import 'package:appflowy/features/color_picker/color_picker.dart';
import 'package:appflowy/plugins/database/widgets/cell_editor/extension.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/select_option_entities.pb.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flutter/material.dart';

class OptionColorList extends StatelessWidget {
  const OptionColorList({
    super.key,
    required this.selectedColor,
    required this.onSelectColor,
  });

  final SelectOptionColorPB selectedColor;
  final void Function(SelectOptionColorPB color) onSelectColor;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    final colors = _getColorPickerConfig();
    final selectedAfColor = selectOptionColorToBgAFColor(selectedColor);

    return GridView.custom(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisExtent(
        crossAxisExtent: 48,
        mainAxisSpacing: theme.spacing.l,
        crossAxisSpacing: theme.spacing.l,
      ),
      shrinkWrap: true,
      padding: EdgeInsets.all(theme.spacing.xl),
      physics: const NeverScrollableScrollPhysics(),
      childrenDelegate: SliverChildBuilderDelegate(
        (context, index) {
          final color = colors[index];
          return MobileColorTile(
            colorType: ColorType.background,
            color: color,
            isSelected: selectedAfColor == color,
            onSelect: () => onSelectColor(afColorToSelectOptionColor(color)),
          );
        },
        childCount: colors.length,
      ),
    );
  }

  List<AFColor> _getColorPickerConfig() {
    return [
      BuiltinAFColor('bg-color-14'),
      BuiltinAFColor('bg-color-16'),
      BuiltinAFColor('bg-color-18'),
      BuiltinAFColor('bg-color-2'),
      BuiltinAFColor('bg-color-4'),
      BuiltinAFColor('bg-color-6'),
      BuiltinAFColor('bg-color-8'),
      BuiltinAFColor('bg-color-10'),
      BuiltinAFColor('bg-color-12'),
      BuiltinAFColor('bg-color-20'),
    ];
  }
}
