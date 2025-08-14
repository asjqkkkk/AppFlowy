import 'package:appflowy/features/mension_person/presentation/mention_menu_service.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:visibility_detector/visibility_detector.dart';

class PersonToolTip extends StatefulWidget {
  const PersonToolTip({
    super.key,
    required this.child,
    required this.person,
    required this.sendNotification,
    required this.isMyself,
    required this.selected,
    required this.scrollController,
  });

  final Widget child;
  final MentionablePersonPB person;
  final bool sendNotification;
  final bool isMyself;
  final bool selected;
  final AutoScrollController scrollController;

  @override
  State<PersonToolTip> createState() => _PersonToolTipState();
}

class _PersonToolTipState extends State<PersonToolTip> {
  final popoverController = PopoverController();
  final globalKey = GlobalKey();
  static OverlayEntry? _overlayEntry;

  MentionablePersonPB get person => widget.person;
  String get email => person.email;
  String get name => person.name;
  bool get sendNotification => widget.sendNotification;
  bool get isMyself => widget.isMyself;
  bool get selected => widget.selected;
  AutoScrollController get scrollController => widget.scrollController;
  double visibleFraction = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (selected) show();
    });
    scrollController.addListener(onScrolling);
  }

  @override
  void dispose() {
    if (selected) hide();
    scrollController.removeListener(onScrolling);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      key: globalKey,
      onEnter: (e) {
        show();
      },
      onExit: (e) {
        hide();
      },
      child: VisibilityDetector(
        key: Key(person.uuid),
        onVisibilityChanged: (visibilityInfo) {
          visibleFraction = visibilityInfo.visibleFraction;
          if (!selected || _overlayEntry == null || !mounted) return;
          if (visibleFraction < 0.5) {
            hide();
          }
        },
        child: widget.child,
      ),
    );
  }

  Widget buildTooltip(BuildContext context, bool showAtLeft) {
    final theme = AppFlowyTheme.of(context), spacing = theme.spacing;
    String tooltip =
        LocaleKeys.document_mentionMenu_personItemTooltip.tr(args: [name]);
    if (isMyself) {
      tooltip = LocaleKeys.document_mentionMenu_you.tr();
    } else if (sendNotification) {
      tooltip = LocaleKeys
          .document_mentionMenu_personItemTooltipWithNotification
          .tr(args: [name]);
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 320,
      ),
      child: Align(
        alignment: showAtLeft ? Alignment.centerRight : Alignment.centerLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.surfaceColorScheme.inverse,
            borderRadius: BorderRadius.circular(spacing.m),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.m,
              vertical: spacing.l,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tooltip,
                  style: theme.textStyle.body
                      .enhanced(color: theme.textColorScheme.onFill),
                ),
                Text(
                  email,
                  style: theme.textStyle.body
                      .standard(color: theme.textColorScheme.secondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void show() {
    final renderbox =
        globalKey.currentContext?.findRenderObject() as RenderBox?;
    final mentionInfo = context.read<MentionMenuServiceInfo>(),
        editorState = mentionInfo.editorState,
        editorRenderBox = editorState.renderBox;
    if (renderbox == null || editorRenderBox == null) return;

    final editorOffset = editorRenderBox.localToGlobal(Offset.zero),
        editorSize = editorRenderBox.size,
        widgetOffset = renderbox.localToGlobal(Offset.zero),
        widgetSize = renderbox.size,
        tooltipWidth = 320,
        horizontalPadding = 2;
    final overRight = widgetOffset.dx + widgetSize.width + tooltipWidth >
            editorOffset.dx + editorSize.width,
        overLeft = widgetOffset.dx - tooltipWidth < 0;
    double left = widgetOffset.dx + widgetSize.width + horizontalPadding,
        top = widgetOffset.dy - 6;
    if (overRight && overLeft) {
      left = editorOffset.dx + editorSize.width - tooltipWidth;
    } else if (overRight) {
      left = widgetOffset.dx - tooltipWidth - horizontalPadding;
    }

    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: left,
          top: top,
          child: buildTooltip(context, overRight),
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void onScrolling() {
    if (!selected ||
        _overlayEntry == null ||
        !mounted ||
        visibleFraction < 0.5) {
      return;
    }
    show();
  }
}
