import 'package:appflowy/features/color_picker/color_picker.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/shared/list_extension.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:universal_platform/universal_platform.dart';

class AppFlowyRichTextTokenKeys {
  static const textColor = 'af_text_color';
  static const backgroundColor = 'af_background_color';
}

class EditorFontColors {
  static final lightColors = [
    const Color(0x00FFFFFF),
    const Color(0xFFE8E0FF),
    const Color(0xFFFFE6FD),
    const Color(0xFFFFDAE6),
    const Color(0xFFFFEFE3),
    const Color(0xFFF5FFDC),
    const Color(0xFFDDFFD6),
    const Color(0xFFDEFFF1),
    const Color(0xFFE1FBFF),
    const Color(0xFFFFADAD),
    const Color(0xFFFFE088),
    const Color(0xFFA7DF4A),
    const Color(0xFFD4C0FF),
    const Color(0xFFFDB2FE),
    const Color(0xFFFFD18B),
    const Color(0xFF65E7F0),
    const Color(0xFF71E6B4),
    const Color(0xFF80F1FF),
  ];

  static final darkColors = [
    const Color(0x00FFFFFF),
    const Color(0xFF8B80AD),
    const Color(0xFF987195),
    const Color(0xFF906D78),
    const Color(0xFFA68B77),
    const Color(0xFF88936D),
    const Color(0xFF72936B),
    const Color(0xFF6B9483),
    const Color(0xFF658B90),
    const Color(0xFF95405A),
    const Color(0xFFA6784D),
    const Color(0xFF6E9234),
    const Color(0xFF6455A2),
    const Color(0xFF924F83),
    const Color(0xFFA48F34),
    const Color(0xFF29A3AC),
    const Color(0xFF2E9F84),
    const Color(0xFF405EA6),
  ];

  // if the input color doesn't exist in the list, return the input color itself.
  static Color? fromBuiltInColors(BuildContext context, Color? color) {
    if (color == null) {
      return null;
    }

    final brightness = Theme.of(context).brightness;

    // if the dark mode color using light mode, return it's corresponding light color. Same for light mode.
    if (brightness == Brightness.light) {
      if (darkColors.contains(color)) {
        return lightColors[darkColors.indexOf(color)];
      }
    } else {
      if (lightColors.contains(color)) {
        return darkColors[lightColors.indexOf(color)];
      }
    }
    return color;
  }
}

List<AFColor> getColorsInSelection(
  EditorState editorState,
  ColorType colorType,
) {
  final selection = editorState.selection?.normalized;

  if (selection == null) {
    return [];
  }

  final (colorKey, tokenKey, defaultColor) = switch (colorType) {
    ColorType.text => (
        AppFlowyRichTextKeys.textColor,
        AppFlowyRichTextTokenKeys.textColor,
        'text-default',
      ),
    ColorType.background => (
        AppFlowyRichTextKeys.backgroundColor,
        AppFlowyRichTextTokenKeys.backgroundColor,
        'bg-default',
      ),
  };

  if (selection.isCollapsed) {
    final String? toggledStyle = editorState.toggledStyle[tokenKey] ??
        editorState.toggledStyle[colorKey];

    if (toggledStyle != null) {
      return [AFColor.fromValue(toggledStyle)];
    }

    final targetSelection = selection.copyWith(
      start: selection.start.copyWith(
        offset: selection.startIndex - 1,
      ),
    );
    String colorValue = editorState.getDeltaAttributeValueInSelection<String>(
          tokenKey,
          targetSelection,
        ) ??
        editorState.getDeltaAttributeValueInSelection<String>(
          colorKey,
          targetSelection,
        ) ??
        defaultColor;
    if (colorValue.isEmpty) {
      colorValue = defaultColor;
    }
    return [AFColor.fromValue(colorValue)];
  }

  final colors = <String>[];
  final nodes = editorState.getNodesInSelection(selection);

  for (var i = 0; i < nodes.length; i++) {
    Delta? delta = nodes[i].delta;
    if (delta == null || delta.isEmpty) {
      continue;
    }

    if (nodes.length == 1) {
      delta = delta.slice(selection.start.offset, selection.end.offset);
    } else if (i == 0) {
      delta = delta.slice(selection.start.offset);
    } else if (i == nodes.length - 1) {
      delta = delta.slice(0, selection.end.offset);
    }

    delta.whereType<TextInsert>().map((delta) => delta.attributes).forEach(
      (attr) {
        String color = attr?[tokenKey] ?? attr?[colorKey] ?? defaultColor;
        if (color.isEmpty) {
          color = defaultColor;
        }
        colors.add(color);
      },
    );
  }

  return colors.unique().map(AFColor.fromValue).toList();
}

void formatColor(
  EditorState editorState,
  AppFlowyThemeData theme,
  ColorType colorType,
  AFColor? color,
) {
  final (colorKey, tokenKey) = switch (colorType) {
    ColorType.text => (
        AppFlowyRichTextKeys.textColor,
        AppFlowyRichTextTokenKeys.textColor,
      ),
    ColorType.background => (
        AppFlowyRichTextKeys.backgroundColor,
        AppFlowyRichTextTokenKeys.backgroundColor,
      ),
  };

  final String? colorHex;
  final String? colorToken;

  switch (color) {
    case null:
      colorHex = null;
      colorToken = null;
    case CustomAFColor():
      colorHex = color.value;
      colorToken = null;
    case BuiltinAFColor():
      final colorValue = color.toColor(theme);
      colorHex = colorValue?.toHex();
      colorToken = color.value;
  }

  final selection = editorState.selection;

  if (selection == null) {
    return;
  }

  if (selection.isCollapsed) {
    editorState
      ..updateToggledStyle(colorKey, colorHex)
      ..updateToggledStyle(tokenKey, colorToken);
    return;
  }

  editorState.formatDelta(
    selection,
    {
      colorKey: colorHex,
      tokenKey: colorToken,
    },
    selectionExtraInfo: UniversalPlatform.isMobile
        ? {
            selectionExtraInfoDisableFloatingToolbar: true,
            selectionExtraInfoDisableMobileToolbarKey: true,
            selectionExtraInfoDoNotAttachTextService: true,
          }
        : null,
  );
}

ColorPickerConfig getTextColorPickerConfig({
  required bool isPro,
  required String workspaceId,
  required String userId,
}) {
  return isPro
      ? ColorPickerConfig(
          title: LocaleKeys.document_toolbar_textColor.tr(),
          colorType: ColorType.text,
          maxColorLimit: 6,
          key: 'doc_text',
          innerKey: '${workspaceId}_$userId',
          defaultColor: BuiltinAFColor('text-default'),
          builtinColors: [
            BuiltinAFColor('text-color-19'),
            BuiltinAFColor('text-color-17'),
            BuiltinAFColor('text-color-15'),
            BuiltinAFColor('text-color-13'),
            BuiltinAFColor('text-color-11'),
            BuiltinAFColor('text-color-9'),
            BuiltinAFColor('text-color-7'),
            BuiltinAFColor('text-color-5'),
            BuiltinAFColor('text-color-3'),
            BuiltinAFColor('text-color-1'),
          ],
        )
      : ColorPickerConfig(
          title: LocaleKeys.document_toolbar_textColor.tr(),
          colorType: ColorType.text,
          maxColorLimit: 6,
          key: 'doc_text',
          innerKey: '${workspaceId}_$userId',
          defaultColor: BuiltinAFColor('text-default'),
          builtinColors: [
            BuiltinAFColor('text-color-19'),
            BuiltinAFColor('text-color-17'),
            BuiltinAFColor('text-color-15'),
            BuiltinAFColor('text-color-11'),
            BuiltinAFColor('text-color-7'),
            BuiltinAFColor('text-color-5'),
            BuiltinAFColor('text-color-3'),
          ],
        );
}

ColorPickerConfig getBackgroundColorPickerConfig({
  required bool isPro,
  required String workspaceId,
  required String userId,
}) {
  return isPro
      ? ColorPickerConfig(
          title: LocaleKeys.document_toolbar_textColor.tr(),
          maxColorLimit: 6,
          colorType: ColorType.background,
          key: 'doc_bg',
          innerKey: '${workspaceId}_$userId',
          defaultColor: BuiltinAFColor('bg-default'),
          builtinColors: [
            BuiltinAFColor('bg-color-19'),
            BuiltinAFColor('bg-color-17'),
            BuiltinAFColor('bg-color-15'),
            BuiltinAFColor('bg-color-13'),
            BuiltinAFColor('bg-color-11'),
            BuiltinAFColor('bg-color-9'),
            BuiltinAFColor('bg-color-7'),
            BuiltinAFColor('bg-color-5'),
            BuiltinAFColor('bg-color-3'),
            BuiltinAFColor('bg-color-1'),
          ],
        )
      : ColorPickerConfig(
          title: LocaleKeys.document_toolbar_backgroundColor.tr(),
          colorType: ColorType.background,
          maxColorLimit: 6,
          key: 'doc_bg',
          innerKey: '${workspaceId}_$userId',
          defaultColor: BuiltinAFColor('bg-default'),
          builtinColors: [
            BuiltinAFColor('bg-color-19'),
            BuiltinAFColor('bg-color-17'),
            BuiltinAFColor('bg-color-15'),
            BuiltinAFColor('bg-color-11'),
            BuiltinAFColor('bg-color-7'),
            BuiltinAFColor('bg-color-5'),
            BuiltinAFColor('bg-color-3'),
          ],
        );
}
