import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/simple_table/simple_table.dart';
import 'package:appflowy/workspace/presentation/widgets/pop_up_action.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

enum OptionAlignType {
  left,
  center,
  right;

  static OptionAlignType fromString(String? value) {
    return switch (value) {
      'left' => OptionAlignType.left,
      'center' => OptionAlignType.center,
      'right' => OptionAlignType.right,
      _ => OptionAlignType.center
    };
  }

  FlowySvgData get svg {
    return switch (this) {
      OptionAlignType.left => FlowySvgs.table_align_left_s,
      OptionAlignType.center => FlowySvgs.table_align_center_s,
      OptionAlignType.right => FlowySvgs.table_align_right_s
    };
  }

  String get description {
    return switch (this) {
      OptionAlignType.left =>
        LocaleKeys.document_plugins_optionAction_left.tr(),
      OptionAlignType.center =>
        LocaleKeys.document_plugins_optionAction_center.tr(),
      OptionAlignType.right =>
        LocaleKeys.document_plugins_optionAction_right.tr()
    };
  }
}

class AlignOptionButton extends StatefulWidget {
  const AlignOptionButton({
    super.key,
    required this.editorState,
    required this.mutex,
    required this.controller,
  });

  final EditorState editorState;
  final PopoverMutex mutex;
  final PopoverController controller;

  @override
  State<AlignOptionButton> createState() => _AlignOptionButtonState();
}

class _AlignOptionButtonState extends State<AlignOptionButton> {
  final innerController = PopoverController();
  bool isOpen = false;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return AppFlowyPopover(
      mutex: widget.mutex,
      controller: innerController,
      clickHandler: PopoverClickHandler.gestureDetector,
      animationDuration: Durations.short3,
      beginScaleFactor: 1.0,
      beginOpacity: 0.8,
      onOpen: () => isOpen = true,
      onClose: () => isOpen = false,
      popupBuilder: (popoverContext) {
        return IntrinsicHeight(
          child: IntrinsicWidth(
            child: Column(
              children: buildAlignOptions(
                context,
                (align) async {
                  await onAlignChanged(align);
                  if (popoverContext.mounted) {
                    PopoverContainer.of(popoverContext).closeAll();
                  }
                },
              ),
            ),
          ),
        );
      },
      child: AFMenuItem(
        onTap: () {
          if (!isOpen) {
            innerController.show();
            isOpen = true;
          }
        },
        leading: FlowySvg(
          align.svg,
          size: Size.square(16),
        ),
        title: Text(
          LocaleKeys.document_plugins_optionAction_align.tr(),
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

  List<Widget> buildAlignOptions(
    BuildContext context,
    void Function(OptionAlignType) onTap,
  ) {
    return OptionAlignType.values.map((e) => OptionAlignWrapper(e)).map((e) {
      final leftIcon = e.leftIcon(Theme.of(context).colorScheme.onSurface);
      final rightIcon = e.rightIcon(Theme.of(context).colorScheme.onSurface);
      return HoverButton(
        onTap: () => onTap(e.inner),
        itemHeight: ActionListSizes.itemHeight,
        leftIcon: SizedBox(
          width: 16,
          height: 16,
          child: leftIcon,
        ),
        name: e.name,
        rightIcon: rightIcon,
      );
    }).toList();
  }

  OptionAlignType get align {
    final selection = widget.editorState.selection;
    if (selection == null) {
      return OptionAlignType.center;
    }
    final node = widget.editorState.getNodeAtPath(selection.start.path);
    final align = node?.type == SimpleTableBlockKeys.type
        ? node?.tableAlign.key
        : node?.attributes[blockComponentAlign];
    return OptionAlignType.fromString(align);
  }

  Future<void> onAlignChanged(OptionAlignType align) async {
    if (align == this.align) {
      return;
    }
    final selection = widget.editorState.selection;
    if (selection == null) {
      return;
    }
    final node = widget.editorState.getNodeAtPath(selection.start.path);
    if (node == null) {
      return;
    }
    // the align attribute for simple table is not same as the align type,
    // so we need to convert the align type to the align attribute
    if (node.type == SimpleTableBlockKeys.type) {
      await widget.editorState.updateTableAlign(
        tableNode: node,
        align: TableAlign.fromString(align.name),
      );
    } else {
      final transaction = widget.editorState.transaction;
      transaction.updateNode(node, {
        blockComponentAlign: align.name,
      });
      await widget.editorState.apply(transaction);
    }
  }
}

class OptionAlignWrapper extends ActionCell {
  OptionAlignWrapper(this.inner);

  final OptionAlignType inner;

  @override
  Widget? leftIcon(Color iconColor) => FlowySvg(inner.svg);

  @override
  String get name => inner.description;
}
