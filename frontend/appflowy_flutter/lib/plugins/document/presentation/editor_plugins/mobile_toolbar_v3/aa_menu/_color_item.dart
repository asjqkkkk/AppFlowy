import 'package:appflowy/features/color_picker/color_picker.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/base/font_colors.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/mobile_toolbar_v3/aa_menu/text_background_color_bottom_sheet.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/mobile_toolbar_v3/aa_menu/_toolbar_theme.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/plugins.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flutter/material.dart';

class ColorItem extends StatelessWidget {
  const ColorItem({
    super.key,
    required this.editorState,
    required this.service,
  });

  final EditorState editorState;
  final AppFlowyMobileToolbarWidgetService service;

  @override
  Widget build(BuildContext context) {
    final toolbarExtension = ToolbarColorExtension.of(context);
    final theme = AppFlowyTheme.of(context);

    final textColors = getColorsInSelection(
      editorState,
      ColorType.text,
    );
    final backgroundColors = getColorsInSelection(
      editorState,
      ColorType.background,
    );

    return MobileToolbarMenuItemWrapper(
      size: const Size(82, 52),
      onTap: () {
        service.closeKeyboard();
        showTextAndBackgroundColorPicker(
          context,
          textColors: textColors,
          backgroundColors: backgroundColors,
          editorState: editorState,
        );
      },
      icon: Stack(
        alignment: Alignment.center,
        children: [
          FlowySvg(
            FlowySvgs.text_color_border_m,
            color: getSingularColor(textColors, theme),
            size: const Size.square(24),
          ),
          FlowySvg(
            FlowySvgs.text_color_m,
            color: getSingularColor(textColors, theme),
            size: const Size.square(24),
          ),
        ],
      ),
      backgroundColor: getSingularColor(backgroundColors, theme) ??
          toolbarExtension.toolbarMenuItemBackgroundColor,
      isSelected: false,
      showRightArrow: true,
      iconPadding: const EdgeInsets.only(
        top: 14.0,
        bottom: 14.0,
        right: 28.0,
      ),
    );
  }

  Color? getSingularColor(List<AFColor> colors, AppFlowyThemeData theme) {
    final color = colors.singleOrNull?.toColor(theme);

    if (color == null || color.a == 0.0) {
      return null;
    }

    return color;
  }
}
