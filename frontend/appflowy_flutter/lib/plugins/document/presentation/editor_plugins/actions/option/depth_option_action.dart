import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/plugins.dart';
import 'package:appflowy/workspace/presentation/widgets/pop_up_action.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

enum OptionDepthType {
  h1(1, 'H1'),
  h2(2, 'H2'),
  h3(3, 'H3'),
  h4(4, 'H4'),
  h5(5, 'H5'),
  h6(6, 'H6');

  const OptionDepthType(this.level, this.description);

  final String description;
  final int level;

  static OptionDepthType fromLevel(int? level) {
    return switch (level) {
      1 => OptionDepthType.h1,
      2 => OptionDepthType.h2,
      3 => OptionDepthType.h3,
      _ => OptionDepthType.h3
    };
  }
}

class DepthOptionButton extends StatefulWidget {
  const DepthOptionButton({
    super.key,
    required this.editorState,
    required this.mutex,
    required this.controller,
  });

  final EditorState editorState;
  final PopoverMutex mutex;
  final PopoverController controller;

  @override
  State<DepthOptionButton> createState() => _DepthOptionButtonState();
}

class _DepthOptionButtonState extends State<DepthOptionButton> {
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
        return DepthOptionMenu(
          onTap: (depth) async {
            await onDepthChanged(depth);
            if (popoverContext.mounted) {
              PopoverContainer.of(popoverContext).closeAll();
            }
          },
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
          OptionAction.depth.svg,
          size: Size.square(16),
        ),
        title: Text(
          LocaleKeys.document_plugins_optionAction_depth.tr(),
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

  Future<void> onDepthChanged(OptionDepthType depth) async {
    final selection = widget.editorState.selection;
    if (selection == null) return;

    final node = widget.editorState.getNodeAtPath(selection.start.path);
    if (node == null) return;

    final level =
        OptionDepthType.fromLevel(node.attributes[OutlineBlockKeys.depth]);
    if (depth == level) return;

    final transaction = widget.editorState.transaction
      ..updateNode(
        node,
        {OutlineBlockKeys.depth: depth.level},
      );
    await widget.editorState.apply(transaction);
  }
}

class DepthOptionMenu extends StatelessWidget {
  const DepthOptionMenu({
    super.key,
    required this.onTap,
  });

  final Future<void> Function(OptionDepthType) onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: buildDepthOptions(context, onTap),
      ),
    );
  }

  List<Widget> buildDepthOptions(
    BuildContext context,
    Future<void> Function(OptionDepthType) onTap,
  ) {
    return OptionDepthType.values
        .map((e) => OptionDepthWrapper(e))
        .map(
          (e) => HoverButton(
            onTap: () => onTap(e.inner),
            itemHeight: ActionListSizes.itemHeight,
            name: e.name,
          ),
        )
        .toList();
  }
}

class OptionDepthWrapper extends ActionCell {
  OptionDepthWrapper(this.inner);

  final OptionDepthType inner;

  @override
  String get name => inner.description;
}
