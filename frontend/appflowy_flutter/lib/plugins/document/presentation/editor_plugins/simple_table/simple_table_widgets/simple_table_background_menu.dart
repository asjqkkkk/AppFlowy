import 'package:appflowy/features/color_picker/color_picker.dart';
import 'package:appflowy/features/workspace/workspace.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/plugins.dart';
import 'package:appflowy/shared/flowy_tint_colors.dart';
import 'package:appflowy_editor/appflowy_editor.dart' hide ColorPicker;
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SimpleTableBackgroundColorMenu extends StatelessWidget {
  const SimpleTableBackgroundColorMenu({
    super.key,
    required this.type,
    required this.tableCellNode,
    this.mutex,
  });

  final SimpleTableMoreActionType type;
  final Node tableCellNode;
  final PopoverMutex? mutex;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = switch (type) {
      SimpleTableMoreActionType.row => tableCellNode.buildRowColor(context),
      SimpleTableMoreActionType.column =>
        tableCellNode.buildColumnColor(context),
    };

    final backgroundAFColor = backgroundColor != null
        ? FlowyTint.fromId(backgroundColor)?.toAFColor()
        : null;

    final isPro = context.read<UserWorkspaceBloc>().state.isInProPlan;

    return AppFlowyPopover(
      mutex: mutex,
      popupBuilder: (popoverContext) {
        return _buildColorOptionMenu(
          isPro,
          context.read<EditorState>(),
          backgroundAFColor,
          () => PopoverContainer.of(popoverContext).closeAll(),
        );
      },
      margin: EdgeInsets.zero,
      child: SimpleTableBasicButton(
        leftIconBuilder: (onHover) => ColorTileIcon(
          color: backgroundAFColor,
        ),
        text: LocaleKeys.document_plugins_simpleTable_moreActions_color.tr(),
        onTap: () {},
      ),
    );
  }

  Widget _buildColorOptionMenu(
    bool isPro,
    EditorState editorState,
    AFColor? selectedColor,
    VoidCallback onClose,
  ) {
    final colorPickerConfig = getColorPickerConfig(isPro);

    return ColorPicker(
      config: colorPickerConfig,
      selectedColors: selectedColor == null ? [] : [selectedColor],
      onSelectColor: (color) {
        final savedColor = color != null
            ? (FlowyTint.fromAFColor(color)?.id ??
                optionActionColorDefaultColor)
            : optionActionColorDefaultColor;

        switch (type) {
          case SimpleTableMoreActionType.column:
            editorState.updateColumnBackgroundColor(
              tableCellNode: tableCellNode,
              color: savedColor,
            );
          case SimpleTableMoreActionType.row:
            editorState.updateRowBackgroundColor(
              tableCellNode: tableCellNode,
              color: savedColor,
            );
        }

        onClose();
      },
    );
  }

  ColorPickerConfig getColorPickerConfig(bool isPro) {
    return ColorPickerConfig(
      key: 'simple-table-background',
      colorType: ColorType.background,
      title: LocaleKeys.document_toolbar_backgroundColor.tr(),
      defaultColor: BuiltinAFColor('bg-default'),
      builtinColors: isPro
          ? [
              BuiltinAFColor('bg-color-14'),
              BuiltinAFColor('bg-color-15'),
              BuiltinAFColor('bg-color-16'),
              BuiltinAFColor('bg-color-17'),
              BuiltinAFColor('bg-color-18'),
              BuiltinAFColor('bg-color-1'),
              BuiltinAFColor('bg-color-2'),
              BuiltinAFColor('bg-color-4'),
              BuiltinAFColor('bg-color-5'),
              BuiltinAFColor('bg-color-6'),
              BuiltinAFColor('bg-color-8'),
              BuiltinAFColor('bg-color-10'),
              BuiltinAFColor('bg-color-12'),
              BuiltinAFColor('bg-color-20'),
            ]
          : [
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
