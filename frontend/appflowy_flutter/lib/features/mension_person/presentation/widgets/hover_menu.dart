import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef HoverMenuBuilder = Widget Function(
  BuildContext context,
  PointerEnterEventListener onEnter,
  PointerExitEventListener onExit,
);

class HoverMenu extends StatefulWidget {
  const HoverMenu({
    super.key,
    required this.menuConstraints,
    required this.triggerSize,
    required this.child,
    required this.menuBuilder,
    required this.editorState,
    this.delayToShow = const Duration(milliseconds: 50),
    this.delayToHide = const Duration(milliseconds: 300),
    this.direction = PopoverDirection.topWithLeftAligned,
    this.offset = Offset.zero,
    this.enable = true,
    this.onEnter,
    this.onExit,
  });

  final BoxConstraints menuConstraints;
  final Size triggerSize;
  final Widget child;
  final HoverMenuBuilder menuBuilder;
  final Duration delayToShow;
  final Duration delayToHide;
  final PopoverDirection direction;
  final Offset offset;
  final PointerEnterEventListener? onEnter;
  final PointerExitEventListener? onExit;
  final bool enable;
  final EditorState editorState;

  @override
  State<HoverMenu> createState() => _HoverMenuState();
}

class _HoverMenuState extends State<HoverMenu> {
  final controller = PopoverController();
  bool isHoverMenuShowing = false;
  bool isHovering = false;
  bool enableHovering = true;

  BoxConstraints get menuConstraints => widget.menuConstraints;
  Size get triggerSize => widget.triggerSize;

  EditorState get editorState => widget.editorState;

  late Selection? _selection = editorState.selection;

  @override
  void initState() {
    super.initState();
    editorState.selectionNotifier.addListener(onSelectionChanged);
  }

  @override
  void dispose() {
    editorState.selectionNotifier.removeListener(onSelectionChanged);
    controller.close();
    isHoverMenuShowing = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.enable && enableHovering
        ? buildHoverMouseRegion(
            buildPopover(),
            cursor: SystemMouseCursors.click,
          )
        : widget.child;
  }

  Widget buildPopover() {
    return AppFlowyPopover(
      controller: controller,
      direction: widget.direction,
      offset: widget.offset,
      onOpen: () {
        keepEditorFocusNotifier.increase();
        isHoverMenuShowing = true;
      },
      onClose: () {
        keepEditorFocusNotifier.decrease();
        isHoverMenuShowing = false;
      },
      margin: EdgeInsets.zero,
      constraints: menuConstraints.copyWith(
        maxHeight: menuConstraints.maxHeight + triggerSize.height,
      ),
      decorationColor: Colors.transparent,
      popoverDecoration: BoxDecoration(),
      popupBuilder: (context) => buildHoverMouseRegion(
        widget.menuBuilder.call(context, onEnter, onExit),
      ),
      child: widget.child,
    );
  }

  Widget buildHoverMouseRegion(
    Widget child, {
    MouseCursor cursor = MouseCursor.defer,
  }) {
    return MouseRegion(
      cursor: cursor,
      onEnter: onEnter,
      onExit: onExit,
      child: child,
    );
  }

  void onEnter(PointerEnterEvent e) {
    widget.onEnter?.call(e);
    isHovering = true;
    Future.delayed(widget.delayToShow, () {
      if (isHovering && !isHoverMenuShowing) {
        showHoverMenu();
      }
    });
  }

  void onExit(PointerExitEvent e) {
    widget.onExit?.call(e);
    isHovering = false;
    tryToDismissenu();
  }

  void showHoverMenu() {
    if (isHoverMenuShowing || !mounted) {
      return;
    }
    keepEditorFocusNotifier.increase();
    controller.show();
    isHoverMenuShowing = true;
  }

  void tryToDismissenu() {
    Future.delayed(widget.delayToHide, () {
      if (isHovering) return;
      keepEditorFocusNotifier.decrease();
      controller.close();
      isHoverMenuShowing = false;
    });
  }

  void onSelectionChanged() {
    final selection = editorState.selection;
    if (selection == null) return;
    if (_selection != selection) {
      _selection = selection;
      if (isHoverMenuShowing) {
        isHoverMenuShowing = false;
        isHovering = false;
        controller.close();
        setState(() {
          enableHovering = false;
        });
        Future.delayed(Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              enableHovering = true;
            });
          }
        });
      }
    }
  }
}
