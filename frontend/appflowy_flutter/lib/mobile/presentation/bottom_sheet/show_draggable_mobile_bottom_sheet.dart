import 'package:appflowy/mobile/presentation/bottom_sheet/drag_handle.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flutter/material.dart';
import 'package:sheet/route.dart';
import 'package:sheet/sheet.dart';

import 'show_transition_bottom_sheet.dart';

Future<T?> showDraggableMobileBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder? headerBuilder,
  required WidgetBuilder builder,
  Widget Function(BuildContext)? sheetContentBuilder,
  bool useRootNavigator = false,
  bool draggable = true,
  Color? backgroundColor,
  Color? barrierColor,
  double initialExtent = 1.0,
  List<double>? stops,
  SheetFit fit = SheetFit.expand,
}) async {
  final theme = AppFlowyTheme.of(context);

  backgroundColor ??= theme.surfaceColorScheme.layer01;
  barrierColor ??= theme.surfaceColorScheme.overlay;

  return Navigator.of(
    context,
    rootNavigator: useRootNavigator,
  ).push<T>(
    DraggableSheetRoute<T>(
      barrierColor: barrierColor,
      initialExtent: initialExtent,
      draggable: draggable,
      stops: stops,
      fit: fit,
      builder: (context) {
        return SafeArea(
          bottom: false,
          child: Material(
            color: Colors.transparent,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(theme.spacing.xl),
                  ),
                ),
                color: backgroundColor,
              ),
              child: sheetContentBuilder?.call(context) ??
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (headerBuilder != null) headerBuilder(context),
                      Expanded(
                        child: builder(context),
                      ),
                    ],
                  ),
            ),
          ),
        );
      },
    ),
  );
}

class DraggableSheetRoute<T> extends SheetRoute<T> {
  DraggableSheetRoute({
    required super.builder,
    super.initialExtent = 1.0,
    super.barrierColor,
    super.fit,
    super.animationCurve,
    super.barrierDismissible,
    super.draggable = true,
    super.stops,
    super.duration,
  });

  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) =>
      previousRoute is! TransitionSheetRoute;
}

class BottomSheetHeaderV2 extends StatelessWidget {
  const BottomSheetHeaderV2({
    super.key,
    required this.title,
    this.showDragHandle = true,
    this.showDivider = true,
    this.leading,
    this.trailing,
  });

  final String title;
  final bool showDragHandle;
  final bool showDivider;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDragHandle) const DragHandle(),
        Container(
          constraints: const BoxConstraints.tightFor(
            height: 52.0,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.xl,
          ),
          child: Stack(
            alignment: AlignmentDirectional.center,
            children: [
              if (leading != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: leading!,
                ),
              Container(
                constraints: const BoxConstraints(maxWidth: 250),
                alignment: AlignmentDirectional.center,
                child: Text(
                  title,
                  style: theme.textStyle.heading4.prominent(
                    color: theme.textColorScheme.primary,
                  ),
                ),
              ),
              if (trailing != null)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: trailing!,
                ),
            ],
          ),
        ),
        if (showDivider) const AFDivider(),
      ],
    );
  }
}
