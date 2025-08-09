import 'package:appflowy/features/color_picker/color_picker.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/database/widgets/cell_editor/extension.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/select_option_entities.pb.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:protobuf/protobuf.dart';

class SelectOptionEditor extends StatefulWidget {
  const SelectOptionEditor({
    super.key,
    required this.option,
    required this.onDeleted,
    required this.onUpdated,
    this.autoFocus = true,
  });

  final SelectOptionPB option;
  final VoidCallback onDeleted;
  final Function(SelectOptionPB) onUpdated;
  final bool autoFocus;

  @override
  State<SelectOptionEditor> createState() => _SelectOptionEditorState();
}

class _SelectOptionEditorState extends State<SelectOptionEditor> {
  late SelectOptionPB option;

  @override
  void initState() {
    super.initState();
    option = widget.option;
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _OptionNameTextField(
          name: option.name,
          autoFocus: widget.autoFocus,
          onSubmitted: (name) => _handleEditOption(name: name),
        ),
        ColorPicker(
          config: _getColorPickerConfig(),
          selectedColors: [
            selectOptionColorToBgAFColor(option.color),
          ],
          onSelectColor: (color) {
            if (color == null) {
              return;
            }
            _handleEditOption(
              color: afColorToSelectOptionColor(color),
            );
          },
        ),
        AFDivider(
          spacing: theme.spacing.m,
        ),
        _DeleteTag(
          onDelete: widget.onDeleted,
        ),
      ],
    );
  }

  void _handleEditOption({
    String? name,
    SelectOptionColorPB? color,
  }) {
    final newOption = option.deepCopy();

    if (name != null) {
      newOption.name = name;
    }
    if (color != null) {
      newOption.color = color;
    }

    widget.onUpdated(newOption);

    setState(() {
      option = newOption;
    });
  }

  ColorPickerConfig _getColorPickerConfig() {
    return ColorPickerConfig(
      key: 'select_option_color',
      title: LocaleKeys.grid_selectOption_colorPanelTitle.tr(),
      colorType: ColorType.background,
      builtinColors: [
        BuiltinAFColor('bg-color-14'),
        BuiltinAFColor('bg-color-16'),
        BuiltinAFColor('bg-color-18'),
        BuiltinAFColor('bg-color-2'),
        BuiltinAFColor('bg-color-4'),
        BuiltinAFColor('bg-color-6'),
        BuiltinAFColor('bg-color-8'),
        BuiltinAFColor('bg-color-10'),
        BuiltinAFColor('bg-color-12'),
        BuiltinAFColor('bg-color-20'),
      ],
      maxColorLimit: 5,
      showCustom: false,
      showRecent: false,
    );
  }
}

class _DeleteTag extends StatelessWidget {
  const _DeleteTag({
    required this.onDelete,
  });

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: theme.spacing.s,
        right: theme.spacing.s,
        bottom: theme.spacing.s,
      ),
      child: AFBaseButton(
        onTap: onDelete,
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.m,
          vertical: theme.spacing.s,
        ),
        borderRadius: theme.spacing.m,
        borderColor: (context, isHovering, disabled, isFocused) =>
            Colors.transparent,
        backgroundColor: (context, isHovering, disabled) => isHovering
            ? theme.fillColorScheme.contentHover
            : theme.fillColorScheme.content,
        builder: (context, isHovering, disabled) {
          return Row(
            spacing: theme.spacing.m,
            children: [
              FlowySvg(
                FlowySvgs.delete_s,
                size: Size.square(20.0),
                color: isHovering
                    ? theme.iconColorScheme.errorThick
                    : theme.iconColorScheme.primary,
              ),
              Expanded(
                child: Text(
                  LocaleKeys.grid_selectOption_deleteTag.tr(),
                  style: TextStyle(
                    color: isHovering
                        ? theme.textColorScheme.error
                        : theme.textColorScheme.primary,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OptionNameTextField extends StatefulWidget {
  const _OptionNameTextField({
    required this.name,
    required this.autoFocus,
    required this.onSubmitted,
  });

  final String name;
  final bool autoFocus;
  final Function(String) onSubmitted;

  @override
  State<_OptionNameTextField> createState() => _OptionNameTextFieldState();
}

class _OptionNameTextFieldState extends State<_OptionNameTextField> {
  final focusNode = FocusNode();
  late final textController = TextEditingController(text: widget.name);

  @override
  void initState() {
    super.initState();
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    textController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Padding(
      padding: EdgeInsets.all(theme.spacing.l),
      child: AFTextField(
        size: AFTextFieldSize.m,
        controller: textController,
        autoFocus: widget.autoFocus,
        focusNode: focusNode,
        onSubmitted: (newName) {
          if (widget.name != newName) {
            widget.onSubmitted(newName);
          }
        },
      ),
    );
  }
}

class SelectOptionTag extends StatelessWidget {
  const SelectOptionTag({
    super.key,
    required this.option,
    this.textStyle,
    this.onRemove,
    this.borderRadius,
    this.padding,
  })  : name = null,
        color = null;

  const SelectOptionTag.custom({
    super.key,
    required this.name,
    required this.color,
    this.textStyle,
    this.onRemove,
    this.borderRadius,
    this.padding,
  }) : option = null;

  final SelectOptionPB? option;
  final String? name;
  final Color? color;
  final TextStyle? textStyle;
  final void Function(String)? onRemove;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    final optionName = option?.name ?? name ?? '';
    final optionColor = option == null
        ? color
        : selectOptionColorToBgAFColor(option!.color).toColor(theme);

    return AFTag(
      text: optionName,
      textStyle: textStyle ??
          theme.textStyle.body.standard(color: theme.textColorScheme.primary),
      color: optionColor,
      padding: padding,
      trailing: onRemove != null
          ? MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => onRemove?.call(optionName),
                behavior: HitTestBehavior.opaque,
                child: FlowySvg(
                  FlowySvgs.close_s,
                  size: Size.square(20.0),
                  color: theme.iconColorScheme.primary,
                ),
              ),
            )
          : null,
    );
  }
}
