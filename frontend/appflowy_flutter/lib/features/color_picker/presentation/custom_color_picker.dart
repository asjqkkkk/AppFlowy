import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

import 'custom_color_palette.dart';

class CustomColorPicker extends StatefulWidget {
  const CustomColorPicker({
    super.key,
    this.initialColor,
    required this.onCancel,
    required this.onCreateCustomColor,
  });

  final Color? initialColor;
  final VoidCallback onCancel;
  final void Function(String) onCreateCustomColor;

  @override
  State<CustomColorPicker> createState() => _CustomColorPickerState();
}

class _CustomColorPickerState extends State<CustomColorPicker> {
  final colorTextController = TextEditingController();

  late final colorFocusNode = FocusNode()..addListener(onColorFocusChange);

  late HSVColor color;

  @override
  void initState() {
    super.initState();
    color = HSVColor.fromColor(widget.initialColor ?? Color(0xFFFFFFFF));
    colorTextController.text = getColorHex(color);
  }

  @override
  void dispose() {
    colorTextController.dispose();
    colorFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Padding(
      padding: EdgeInsets.all(theme.spacing.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: theme.spacing.l,
        children: [
          SaturationAndValue(
            color: color,
            onColorChanged: (newColor) {
              setState(() {
                color = newColor;
                colorTextController.text = getColorHex(color);
              });
            },
          ),
          Hue(
            color: color,
            onColorChanged: (newColor) {
              setState(() {
                color = newColor;
                colorTextController.text = getColorHex(color);
              });
            },
          ),
          Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: Row(
              spacing: theme.spacing.s,
              children: [
                Container(
                  height: 32,
                  width: 32,
                  decoration: BoxDecoration(
                    color: color.toColor(),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.borderColorScheme.primary,
                    ),
                  ),
                ),
                Expanded(
                  child: AFTextField(
                    controller: colorTextController,
                    focusNode: colorFocusNode,
                    size: AFTextFieldSize.m,
                    prefixIconBuilder: (context) {
                      return Container(
                        width: theme.spacing.m,
                        margin: EdgeInsetsDirectional.only(
                          start: theme.spacing.m,
                          end: theme.spacing.s,
                        ),
                        child: Text(
                          '#',
                          textAlign: TextAlign.center,
                          style: theme.textStyle.body.standard(
                            color: theme.textColorScheme.secondary,
                          ),
                        ),
                      );
                    },
                    prefixIconConstraints: BoxConstraints.tightFor(
                      width: 3 * theme.spacing.m,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: theme.spacing.s,
            children: [
              AFOutlinedTextButton.normal(
                text: LocaleKeys.button_cancel.tr(),
                onTap: widget.onCancel,
              ),
              AFFilledTextButton.primary(
                text: LocaleKeys.button_apply.tr(),
                onTap: onApply,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void onColorFocusChange() {
    if (colorFocusNode.hasFocus) {
      colorTextController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: colorTextController.text.length,
      );
    } else {
      setState(() {
        final text = colorTextController.text.trim().replaceAll('#', '');
        final colorValue = '0xFF$text';
        final newColor = Color(int.tryParse(colorValue) ?? 0xFFFFFFFF);

        color = HSVColor.fromColor(newColor).withAlpha(color.alpha);
        colorTextController.text = getColorHex(color);
      });
    }
  }

  String getColorHex(HSVColor hsvColor) {
    final rgbColor = hsvColor.toColor();
    final r = (rgbColor.r * 255)
        .round()
        .toRadixString(16)
        .padLeft(2, '0')
        .toUpperCase();
    final g = (rgbColor.g * 255)
        .round()
        .toRadixString(16)
        .padLeft(2, '0')
        .toUpperCase();
    final b = (rgbColor.b * 255)
        .round()
        .toRadixString(16)
        .padLeft(2, '0')
        .toUpperCase();
    return '$r$g$b';
  }

  void onApply() {
    final rgbColor = color.toColor();
    widget.onCreateCustomColor(rgbColor.toHex());
  }
}
