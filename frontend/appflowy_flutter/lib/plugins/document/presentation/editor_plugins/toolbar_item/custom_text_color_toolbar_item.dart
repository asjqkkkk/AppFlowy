import 'package:appflowy/features/color_picker/color_picker.dart';
import 'package:appflowy/features/workspace/logic/workspace_bloc.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/document/presentation/editor_page.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_editor/appflowy_editor.dart' hide ColorPicker;
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../base/font_colors.dart';
import 'toolbar_id_enum.dart';

final customTextColorItem = ToolbarItem(
  id: ToolbarId.textColor.id,
  group: 1,
  isActive: showInAnyTextType,
  builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) =>
      TextColorPickerWidget(
    editorState: editorState,
    tooltipBuilder: tooltipBuilder,
  ),
);

class TextColorPickerWidget extends StatefulWidget {
  const TextColorPickerWidget({
    super.key,
    required this.editorState,
    this.tooltipBuilder,
  });

  final EditorState editorState;
  final ToolbarTooltipBuilder? tooltipBuilder;

  @override
  State<TextColorPickerWidget> createState() => _TextColorPickerWidgetState();
}

class _TextColorPickerWidgetState extends State<TextColorPickerWidget> {
  late final popoverController = AFPopoverController()
    ..addListener(onPopoverChange);

  @override
  void dispose() {
    super.dispose();
    popoverController.dispose();
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

    final colors = getColorsInSelection(widget.editorState, ColorType.text);

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
          isPro,
          workspaceId,
          userId,
        );
      },
      child: buildChild(colors),
    );
  }

  Widget buildChild(List<AFColor> colors) {
    final theme = AppFlowyTheme.of(context);

    final child = AFBaseButton(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.m,
        vertical: theme.spacing.xs,
      ),
      borderRadius: theme.spacing.m,
      borderColor: (context, isHovering, disabled, isFocused) =>
          Colors.transparent,
      backgroundColor: (context, isHovering, disabled) {
        if (isHovering || popoverController.isOpen) {
          return theme.fillColorScheme.contentHover;
        }
        return theme.fillColorScheme.content;
      },
      builder: (context, isHovering, disabled) {
        final iconColor = colors.singleOrNull?.toColor(theme) ??
            theme.iconColorScheme.primary;

        return SizedBox(
          height: 24,
          child: Stack(
            alignment: Alignment.center,
            children: [
              FlowySvg(
                FlowySvgs.text_color_border_m,
                size: Size.square(20),
                color: iconColor,
              ),
              FlowySvg(
                FlowySvgs.text_color_m,
                size: Size.square(20),
                color: iconColor,
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
          ToolbarId.textColor.id,
          LocaleKeys.document_toolbar_textColor.tr(),
          child,
        ) ??
        child;
  }

  Widget buildPopoverContent(
    List<AFColor> colors,
    bool isPro,
    String workspaceId,
    String userId,
  ) {
    return ColorPicker(
      config: getTextColorPickerConfig(
        isPro: isPro,
        workspaceId: workspaceId,
        userId: userId,
      ),
      selectedColors: colors,
      onSelectColor: (color) {
        formatColor(
          widget.editorState,
          AppFlowyTheme.of(context),
          ColorType.text,
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
