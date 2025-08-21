import 'package:appflowy/features/color_picker/color_picker.dart';
import 'package:appflowy/features/workspace/workspace.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/shared/flowy_tint_colors.dart';
import 'package:appflowy_editor/appflowy_editor.dart' hide ColorPicker;
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const optionActionColorDefaultColor = 'appflowy_theme_default_color';

class ColorOptionButton extends StatefulWidget {
  const ColorOptionButton({
    super.key,
    required this.editorState,
    required this.mutex,
    required this.controller,
  });

  final EditorState editorState;
  final PopoverMutex mutex;
  final PopoverController controller;

  @override
  State<ColorOptionButton> createState() => _ColorOptionButtonState();
}

class _ColorOptionButtonState extends State<ColorOptionButton> {
  final innerController = PopoverController();

  bool isOpen = false;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    final selection = widget.editorState.selection?.normalized;
    if (selection == null) {
      return const SizedBox.shrink();
    }

    final node = widget.editorState.getNodeAtPath(selection.start.path);
    if (node == null) {
      return const SizedBox.shrink();
    }

    final bgColor = node.attributes[blockComponentBackgroundColor] as String?;
    final selectedColor = bgColor == null
        ? null
        : FlowyTint.fromId(bgColor)?.toAFColor() ??
            BuiltinAFColor('bg-default');

    return AppFlowyPopover(
      asBarrier: true,
      controller: innerController,
      mutex: widget.mutex,
      margin: EdgeInsets.zero,
      triggerActions: PopoverTriggerFlags.none,
      popupBuilder: (context) {
        isOpen = true;
        return _buildColorOptionMenu(node, selectedColor);
      },
      onClose: () => isOpen = false,
      direction: PopoverDirection.rightWithCenterAligned,
      animationDuration: Durations.short3,
      beginScaleFactor: 1.0,
      beginOpacity: 0.8,
      child: AFMenuItem(
        onTap: () {
          if (!isOpen) {
            innerController.show();
            isOpen = true;
          }
        },
        leading: SizedBox.square(
          dimension: 16.0,
          child: ColorTileIcon(
            color: selectedColor,
          ),
        ),
        title: Text(
          LocaleKeys.document_plugins_optionAction_color.tr(),
          style: theme.textStyle.body.standard(
            color: theme.textColorScheme.primary,
          ),
        ),
        trailing: (context, isHovering, disabled) => FlowySvg(
          FlowySvgs.toolbar_arrow_right_m,
          color: theme.iconColorScheme.tertiary,
          size: Size.square(20),
        ),
      ),
    );
  }

  Widget _buildColorOptionMenu(Node node, AFColor? selectedColor) {
    final colorPickerConfig = ColorPickerConfig(
      key: '',
      colorType: ColorType.background,
      title: LocaleKeys.document_toolbar_backgroundColor.tr(),
      defaultColor: BuiltinAFColor('bg-default'),
      builtinColors: context.read<UserWorkspaceBloc>().state.isInProPlan
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

    return ColorPicker(
      config: colorPickerConfig,
      selectedColors: selectedColor == null ? [] : [selectedColor],
      onSelectColor: (color) {
        _applyColorToSelection(node, color);
      },
    );
  }

  void _applyColorToSelection(Node node, AFColor? color) async {
    final editorState = widget.editorState;
    final transaction = editorState.transaction;
    final selection = editorState.selection;

    final savedColor = color != null
        ? (FlowyTint.fromAFColor(color)?.id ?? optionActionColorDefaultColor)
        : optionActionColorDefaultColor;

    // In multiple selection, we need to update all the nodes in the selection
    if (editorState.selectionType == SelectionType.block && selection != null) {
      final nodes = editorState.getNodesInSelection(selection.normalized);
      for (final node in nodes) {
        transaction.updateNode(node, {
          blockComponentBackgroundColor: savedColor,
        });
      }
    } else {
      transaction.updateNode(node, {
        blockComponentBackgroundColor: savedColor,
      });
    }

    await widget.editorState.apply(transaction);

    innerController.close();
    widget.controller.close();
  }
}
