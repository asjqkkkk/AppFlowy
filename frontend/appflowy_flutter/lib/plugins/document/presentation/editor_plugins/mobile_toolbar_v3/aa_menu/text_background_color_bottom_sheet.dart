import 'package:appflowy/features/color_picker/color_picker.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/bottom_sheet.dart';
import 'package:appflowy/workspace/application/user/prelude.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../base/font_colors.dart';

Future<void> showTextAndBackgroundColorPicker(
  BuildContext context, {
  required List<AFColor> textColors,
  required List<AFColor> backgroundColors,
  required EditorState editorState,
}) async {
  final theme = AppFlowyTheme.of(context);

  final userWorkspaceState = context.read<UserWorkspaceBloc>().state;

  final workspaceId = userWorkspaceState.currentWorkspace?.workspaceId ?? '';
  final userId = userWorkspaceState.userProfile.id.toString();

  final subscriptionPlan = userWorkspaceState.workspaceSubscriptionInfo;

  final isPro = subscriptionPlan != null &&
      subscriptionPlan.plan == SubscriptionPlanPB.Pro;

  await showMobileBottomSheet(
    context,
    showHeader: true,
    showDragHandle: true,
    showDoneButton: true,
    showDivider: false,
    showCloseButton: true,
    barrierColor: Colors.transparent,
    title: LocaleKeys.grid_selectOption_colorPanelTitle.tr(),
    elevation: 20,
    enablePadding: false,
    builder: (sheetContext) {
      return Flexible(
        child: MobileColorPicker(
          textColorConfig: getTextColorPickerConfig(
            isPro: isPro,
            workspaceId: workspaceId,
            userId: userId,
          ),
          selectedTextColors: textColors,
          onSelectTextColor: (color) {
            formatColor(
              editorState,
              theme,
              ColorType.text,
              color,
            );
          },
          backgroundColorConfig: getBackgroundColorPickerConfig(
            isPro: isPro,
            workspaceId: workspaceId,
            userId: userId,
          ),
          selectedBackgroundColors: backgroundColors,
          onSelectBackgroundColor: (color) {
            formatColor(
              editorState,
              theme,
              ColorType.background,
              color,
            );
          },
        ),
      );
    },
  );

  Future.delayed(const Duration(milliseconds: 100), () {
    // highlight the selected text again.
    final selection = editorState.selection;
    if (selection == null) {
      return;
    }
    editorState.updateSelectionWithReason(
      selection,
      extraInfo: {
        selectionExtraInfoDisableFloatingToolbar: true,
      },
    );
  });
}
