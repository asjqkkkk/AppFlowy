import 'package:appflowy/features/color_picker/color_picker.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/base/font_colors.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/mobile_toolbar_v3/aa_menu/text_background_color_bottom_sheet.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/plugins.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flutter/widgets.dart';

import 'link_toolbar_item.dart';

final boldToolbarItem = AppFlowyMobileToolbarItem(
  itemBuilder: (context, editorState, _, __, onAction) {
    return AppFlowyMobileToolbarIconItem(
      editorState: editorState,
      shouldListenToToggledStyle: true,
      isSelected: () =>
          editorState.isTextDecorationSelected(
            AppFlowyRichTextKeys.bold,
          ) &&
          editorState.toggledStyle[AppFlowyRichTextKeys.bold] != false,
      icon: FlowySvgs.m_toolbar_bold_m,
      onTap: () async => editorState.toggleAttribute(
        AppFlowyRichTextKeys.bold,
        selectionExtraInfo: {
          selectionExtraInfoDisableFloatingToolbar: true,
        },
      ),
    );
  },
);

final italicToolbarItem = AppFlowyMobileToolbarItem(
  itemBuilder: (context, editorState, _, __, onAction) {
    return AppFlowyMobileToolbarIconItem(
      editorState: editorState,
      shouldListenToToggledStyle: true,
      isSelected: () => editorState.isTextDecorationSelected(
        AppFlowyRichTextKeys.italic,
      ),
      icon: FlowySvgs.m_toolbar_italic_m,
      onTap: () async => editorState.toggleAttribute(
        AppFlowyRichTextKeys.italic,
        selectionExtraInfo: {
          selectionExtraInfoDisableFloatingToolbar: true,
        },
      ),
    );
  },
);

final underlineToolbarItem = AppFlowyMobileToolbarItem(
  itemBuilder: (context, editorState, _, __, onAction) {
    return AppFlowyMobileToolbarIconItem(
      editorState: editorState,
      shouldListenToToggledStyle: true,
      isSelected: () => editorState.isTextDecorationSelected(
        AppFlowyRichTextKeys.underline,
      ),
      icon: FlowySvgs.m_toolbar_underline_m,
      onTap: () async => editorState.toggleAttribute(
        AppFlowyRichTextKeys.underline,
        selectionExtraInfo: {
          selectionExtraInfoDisableFloatingToolbar: true,
        },
      ),
    );
  },
);

final strikethroughToolbarItem = AppFlowyMobileToolbarItem(
  itemBuilder: (context, editorState, _, __, onAction) {
    return AppFlowyMobileToolbarIconItem(
      editorState: editorState,
      shouldListenToToggledStyle: true,
      isSelected: () => editorState.isTextDecorationSelected(
        AppFlowyRichTextKeys.strikethrough,
      ),
      icon: FlowySvgs.m_toolbar_strike_m,
      onTap: () async => editorState.toggleAttribute(
        AppFlowyRichTextKeys.strikethrough,
        selectionExtraInfo: {
          selectionExtraInfoDisableFloatingToolbar: true,
        },
      ),
    );
  },
);

final colorToolbarItem = AppFlowyMobileToolbarItem(
  itemBuilder: (context, editorState, service, _, onAction) {
    final theme = AppFlowyTheme.of(context);

    final textColors = getColorsInSelection(
      editorState,
      ColorType.text,
    );
    final backgroundColors = getColorsInSelection(
      editorState,
      ColorType.background,
    );

    Color? getSingularColor(List<AFColor> colors) {
      final color = colors.singleOrNull?.toColor(theme);

      if (color == null || color.a == 0.0) {
        return null;
      }

      return color;
    }

    return AppFlowyMobileToolbarIconItem(
      editorState: editorState,
      shouldListenToToggledStyle: true,
      icon: FlowySvgs.m_aa_font_color_m,
      iconBuilder: (context) {
        final iconColor =
            getSingularColor(textColors) ?? theme.iconColorScheme.primary;
        return Container(
          width: 40,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            color: getSingularColor(backgroundColors),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              FlowySvg(
                FlowySvgs.text_color_border_m,
                size: Size.square(24),
                color: iconColor,
              ),
              FlowySvg(
                FlowySvgs.text_color_m,
                size: Size.square(24),
                color: iconColor,
              ),
            ],
          ),
        );
      },
      onTap: () {
        service.closeKeyboard();
        showTextAndBackgroundColorPicker(
          context,
          editorState: editorState,
          textColors: textColors,
          backgroundColors: backgroundColors,
        );
      },
    );
  },
);

final linkToolbarItem = AppFlowyMobileToolbarItem(
  itemBuilder: (context, editorState, service, __, onAction) {
    return AppFlowyMobileToolbarIconItem(
      editorState: editorState,
      shouldListenToToggledStyle: true,
      icon: FlowySvgs.m_toolbar_link_m,
      onTap: () {
        onMobileLinkButtonTap(editorState);
      },
    );
  },
);
