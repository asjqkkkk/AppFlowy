import 'package:appflowy/features/color_picker/color_picker.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/shared/flowy_tint_colors.dart';
import 'package:appflowy/workspace/presentation/widgets/pop_up_action.dart';
import 'package:appflowy_editor/appflowy_editor.dart' hide ColorPicker;
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flowy_infra_ui/style_widget/extension.dart';
import 'package:flutter/material.dart';

const tableCellDefaultColor = 'appflowy_table_cell_default_color';

enum TableOptionAction {
  addAfter,
  addBefore,
  delete,
  duplicate,
  clear,

  /// row|cell background color
  bgColor;

  Widget icon(Color? color) {
    switch (this) {
      case TableOptionAction.addAfter:
        return const FlowySvg(FlowySvgs.add_s);
      case TableOptionAction.addBefore:
        return const FlowySvg(FlowySvgs.add_s);
      case TableOptionAction.delete:
        return const FlowySvg(FlowySvgs.delete_s);
      case TableOptionAction.duplicate:
        return const FlowySvg(FlowySvgs.copy_s);
      case TableOptionAction.clear:
        return const FlowySvg(FlowySvgs.close_s);
      case TableOptionAction.bgColor:
        return const FlowySvg(
          FlowySvgs.color_format_m,
          size: Size.square(12),
        ).padding(all: 2.0);
    }
  }

  String get description {
    switch (this) {
      case TableOptionAction.addAfter:
        return LocaleKeys.document_plugins_table_addAfter.tr();
      case TableOptionAction.addBefore:
        return LocaleKeys.document_plugins_table_addBefore.tr();
      case TableOptionAction.delete:
        return LocaleKeys.document_plugins_table_delete.tr();
      case TableOptionAction.duplicate:
        return LocaleKeys.document_plugins_table_duplicate.tr();
      case TableOptionAction.clear:
        return LocaleKeys.document_plugins_table_clear.tr();
      case TableOptionAction.bgColor:
        return LocaleKeys.document_plugins_table_bgColor.tr();
    }
  }
}

class TableOptionActionWrapper extends ActionCell {
  TableOptionActionWrapper(this.inner);

  final TableOptionAction inner;

  @override
  Widget? leftIcon(Color iconColor) => inner.icon(iconColor);

  @override
  String get name => inner.description;
}

class TableColorOptionAction extends PopoverActionCell {
  TableColorOptionAction({
    required this.node,
    required this.editorState,
    required this.position,
    required this.dir,
  });

  final Node node;
  final EditorState editorState;
  final int position;
  final TableDirection dir;

  @override
  Widget? leftIcon(Color iconColor) =>
      TableOptionAction.bgColor.icon(iconColor);

  @override
  String get name => TableOptionAction.bgColor.description;

  @override
  Widget Function(
    BuildContext context,
    PopoverController parentController,
    PopoverController controller,
  ) get builder {
    return (context, parentController, controller) {
      int row = 0, col = position;
      if (dir == TableDirection.row) {
        col = 0;
        row = position;
      }

      final cell = node.children.firstWhereOrNull(
        (n) =>
            n.attributes[TableCellBlockKeys.colPosition] == col &&
            n.attributes[TableCellBlockKeys.rowPosition] == row,
      );
      final key = dir == TableDirection.col
          ? TableCellBlockKeys.colBackgroundColor
          : TableCellBlockKeys.rowBackgroundColor;

      final bgColor = cell?.attributes[key] as String?;

      final colorPickerConfig = getColorPickerConfig();

      return ColorPicker(
        config: colorPickerConfig,
        selectedColors: bgColor == null ? [] : [AFColor.fromValue(bgColor)],
        onSelectColor: (color) {
          final savedColor =
              color == null ? '' : FlowyTint.fromAFColor(color)?.id ?? '';

          TableActions.setBgColor(
            node,
            position,
            editorState,
            savedColor,
            dir,
          );
        },
      );
    };
  }

  ColorPickerConfig getColorPickerConfig() {
    return ColorPickerConfig(
      key: 'table-background',
      colorType: ColorType.background,
      title: LocaleKeys.document_toolbar_backgroundColor.tr(),
      defaultColor: BuiltinAFColor('bg-default'),
      builtinColors: [
        BuiltinAFColor('bg-color-14'),
        BuiltinAFColor('bg-color-16'),
        BuiltinAFColor('bg-color-18'),
        BuiltinAFColor('bg-color-2'),
        BuiltinAFColor('bg-color-4'),
        BuiltinAFColor('bg-color-6'),
        BuiltinAFColor('bg-color-8'),
        BuiltinAFColor('bg-color-10'),
        BuiltinAFColor('bg-color-12'),
      ],
      recentColorLimit: 5,
      customColorLimit: 4,
      showRecent: false,
      showCustom: false,
    );
  }
}
