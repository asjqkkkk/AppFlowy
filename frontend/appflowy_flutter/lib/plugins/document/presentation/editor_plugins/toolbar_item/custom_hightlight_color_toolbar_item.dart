import 'package:appflowy/features/color_picker/color_picker.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/document/presentation/editor_page.dart';
import 'package:appflowy/workspace/application/user/prelude.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_editor/appflowy_editor.dart' hide ColorPicker;
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../base/font_colors.dart';
import 'toolbar_id_enum.dart';

final customHighlightColorItem = ToolbarItem(
  id: ToolbarId.highlightColor.id,
  group: 1,
  isActive: showInAnyTextType,
  builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) =>
      HighlightColorPickerWidget(
    editorState: editorState,
    tooltipBuilder: tooltipBuilder,
  ),
);

class HighlightColorPickerWidget extends StatefulWidget {
  const HighlightColorPickerWidget({
    super.key,
    required this.editorState,
    this.tooltipBuilder,
  });

  final EditorState editorState;
  final ToolbarTooltipBuilder? tooltipBuilder;

  @override
  State<HighlightColorPickerWidget> createState() =>
      _HighlightColorPickerWidgetState();
}

class _HighlightColorPickerWidgetState
    extends State<HighlightColorPickerWidget> {
  late final popoverController = AFPopoverController()
    ..addListener(onPopoverChange);

  @override
  void initState() {
    super.initState();
    final bloc = context.read<UserWorkspaceBloc>();
    bloc.add(
      UserWorkspaceEvent.fetchWorkspaceSubscriptionInfo(
        workspaceId: bloc.state.currentWorkspace?.workspaceId ?? '',
      ),
    );
  }

  @override
  void dispose() {
    popoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.editorState.selection == null) {
      return const SizedBox.shrink();
    }

    final theme = AppFlowyTheme.of(context);

    final userWorkspaceState = context.read<UserWorkspaceBloc>().state;

    final workspaceId = userWorkspaceState.currentWorkspace?.workspaceId ?? '';
    final userId = userWorkspaceState.userProfile.id.toString();

    final subscriptionPlan = userWorkspaceState.workspaceSubscriptionInfo;
    final isPro = subscriptionPlan != null &&
        subscriptionPlan.plan == SubscriptionPlanPB.Pro;

    final colors =
        getColorsInSelection(widget.editorState, ColorType.background);

    final config = getBackgroundColorPickerConfig(
      isPro: isPro,
      workspaceId: workspaceId,
      userId: userId,
    );

    return AFPopover(
      controller: popoverController,
      padding: EdgeInsets.zero,
      anchor: AFAnchorAuto(
        followerAnchor: Alignment.bottomRight,
        targetAnchor: Alignment.centerLeft,
        offset: Offset(0, 2.0 + theme.spacing.xs + 16.0),
      ),
      decoration: BoxDecoration(
        color: theme.surfaceColorScheme.layer01,
        borderRadius: BorderRadius.circular(theme.borderRadius.l),
        boxShadow: theme.shadow.small,
      ),
      popover: (context) {
        return buildPopoverContent(
          colors,
          config,
        );
      },
      child: buildChild(context, colors, config),
    );
  }

  Widget buildChild(
    BuildContext context,
    List<AFColor> colors,
    ColorPickerConfig config,
  ) {
    final theme = AppFlowyTheme.of(context);

    final Color? backgroundColor;
    if (colors.isEmpty || colors.length > 1) {
      backgroundColor = null;
    } else if (colors.first == config.defaultColor) {
      backgroundColor = null;
    } else {
      backgroundColor = colors.first.toColor(theme);
    }

    final child = AFBaseButton(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.m,
        vertical: theme.spacing.xs,
      ),
      borderColor: (context, isHovering, disabled, isFocused) =>
          Colors.transparent,
      borderRadius: theme.spacing.m,
      backgroundColor: (context, isHovering, disabled) {
        if (isHovering || popoverController.isOpen) {
          return theme.fillColorScheme.contentHover;
        }
        return theme.fillColorScheme.content;
      },
      builder: (context, isHovering, disabled) {
        return SizedBox(
          height: 24,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (backgroundColor == null)
                FlowySvg(
                  FlowySvgs.text_color_border_m,
                  size: Size.square(20),
                  color: theme.iconColorScheme.primary,
                )
              else
                FlowySvg(
                  FlowySvgs.text_color_fill_m,
                  size: Size.square(20),
                  color: backgroundColor,
                ),
              FlowySvg(
                FlowySvgs.text_highlight_m,
                size: Size.square(20),
                color: theme.iconColorScheme.primary,
              ),
            ],
          ),
        );
      },
      onTap: () {
        if (popoverController.isOpen) {
          popoverController.hide();
        } else {
          popoverController.show();
        }
      },
    );

    return widget.tooltipBuilder?.call(
          context,
          ToolbarId.highlightColor.id,
          LocaleKeys.document_toolbar_backgroundColor.tr(),
          child,
        ) ??
        child;
  }

  Widget buildPopoverContent(
    List<AFColor> colors,
    ColorPickerConfig config,
  ) {
    return ColorPicker(
      config: config,
      selectedColors: colors,
      onSelectColor: (color) {
        formatColor(
          widget.editorState,
          AppFlowyTheme.of(context),
          ColorType.background,
          color,
        );
      },
    );
  }

  void onPopoverChange() {
    setState(() {
      if (popoverController.isOpen) {
        keepEditorFocusNotifier.increase();
      } else {
        keepEditorFocusNotifier.decrease();
      }
    });
  }
}
