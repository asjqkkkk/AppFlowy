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
    required this.isPro,
  });

  final SelectOptionColorPB selectedColor;
  final void Function(SelectOptionColorPB color) onSelectColor;
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    final colors = _getAFColors();
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

  List<AFColor> _getAFColors() {
    return isPro
        ? [
            BuiltinAFColor('tag-fill-1-light'),
            BuiltinAFColor('tag-fill-2-light'),
            BuiltinAFColor('tag-fill-3-light'),
            BuiltinAFColor('tag-fill-4-light'),
            BuiltinAFColor('tag-fill-5-light'),
            BuiltinAFColor('tag-fill-6-light'),
            BuiltinAFColor('tag-fill-7-light'),
            BuiltinAFColor('tag-fill-8-light'),
            BuiltinAFColor('tag-fill-9-light'),
            BuiltinAFColor('tag-fill-10-light'),
            BuiltinAFColor('tag-fill-1-thick'),
            BuiltinAFColor('tag-fill-2-thick'),
            BuiltinAFColor('tag-fill-3-thick'),
            BuiltinAFColor('tag-fill-4-thick'),
            BuiltinAFColor('tag-fill-5-thick'),
            BuiltinAFColor('tag-fill-6-thick'),
            BuiltinAFColor('tag-fill-7-thick'),
            BuiltinAFColor('tag-fill-8-thick'),
            BuiltinAFColor('tag-fill-9-thick'),
            BuiltinAFColor('tag-fill-10-thick'),
          ]
        : [
            BuiltinAFColor('tag-fill-1-light'),
            BuiltinAFColor('tag-fill-2-light'),
            BuiltinAFColor('tag-fill-3-light'),
            BuiltinAFColor('tag-fill-4-light'),
            BuiltinAFColor('tag-fill-5-light'),
            BuiltinAFColor('tag-fill-6-light'),
            BuiltinAFColor('tag-fill-7-light'),
            BuiltinAFColor('tag-fill-8-light'),
            BuiltinAFColor('tag-fill-9-light'),
            BuiltinAFColor('tag-fill-10-light'),
          ];
  }
}
