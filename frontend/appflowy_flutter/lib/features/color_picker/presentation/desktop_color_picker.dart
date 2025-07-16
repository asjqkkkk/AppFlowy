import 'package:appflowy/core/config/kv.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/models/af_color.dart';
import '../data/models/color_picker_config.dart';
import '../data/models/color_type.dart';
import '../data/repositories/local_recent_custom_color_repository_impl.dart';
import '../logic/color_picker_bloc.dart';
import '../logic/color_picker_event.dart';
import '../logic/color_picker_state.dart';
import 'color_tile.dart';
import 'custom_color_picker.dart';

class ColorPicker extends StatefulWidget {
  const ColorPicker({
    super.key,
    required this.config,
    required this.selectedColors,
    required this.onSelectColor,
  });

  final ColorPickerConfig config;
  final List<AFColor> selectedColors;

  /// If null, then default is selected
  final void Function(AFColor? color) onSelectColor;

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  bool isCreatingCustomColor = false;
  late final LocalRecentCustomColorRepositoryImpl _repository;

  @override
  void initState() {
    super.initState();
    _repository = LocalRecentCustomColorRepositoryImpl(
      kv: getIt<KeyValueStorage>(),
      key: widget.config.key,
      innerKey: widget.config.innerKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ColorPickerBloc(
        repository: _repository,
        config: widget.config,
      )..add(ColorPickerInitial(widget.selectedColors)),
      child: Builder(
        builder: (context) {
          final theme = AppFlowyTheme.of(context);
          final bloc = context.read<ColorPickerBloc>();

          return isCreatingCustomColor
              ? customColorPicker(bloc, theme)
              : mainColorPicker(bloc, theme);
        },
      ),
    );
  }

  Widget customColorPicker(ColorPickerBloc bloc, AppFlowyThemeData theme) {
    final selectedColor = bloc.state.selectedColor;

    final Color? initialColor;
    switch ((selectedColor, widget.config.colorType)) {
      case (CustomAFColor(), _):
        initialColor = selectedColor!.toColor(theme);
      case (BuiltinAFColor(), ColorType.background):
        initialColor = selectedColor!.toColor(theme)?.withAlpha(153); // 60%
      case (BuiltinAFColor(), _):
        initialColor = selectedColor!.toColor(theme);
      case (null, ColorType.background):
        initialColor = Color(0x99FFFFFF); // 60% white
      case (null, _):
        initialColor = Color(0xFFFFFFFF); // white
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 244,
      ),
      child: CustomColorPicker(
        initialColor: initialColor,
        onCancel: () {
          setState(() => isCreatingCustomColor = false);
        },
        onCreateCustomColor: (colorHex) {
          setState(() {
            final afColor = CustomAFColor(colorHex);
            bloc.add(ColorPickerCreateCustomColor(afColor));
            widget.onSelectColor.call(afColor);
            isCreatingCustomColor = false;
          });
        },
      ),
    );
  }

  Widget mainColorPicker(ColorPickerBloc bloc, AppFlowyThemeData theme) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: (theme.spacing.m + theme.spacing.s) * 2 +
            widget.config.maxColorLimit * 28.0 +
            (widget.config.maxColorLimit - 1) * theme.spacing.m,
      ),
      child: MainColorPicker(
        config: widget.config,
        onSelectColor: (color) {
          if (color == widget.config.defaultColor ||
              bloc.state.selectedColor == color) {
            widget.onSelectColor.call(null);
            bloc.add(ColorPickerUseDefaultColor());
          } else {
            widget.onSelectColor.call(color);
            bloc.add(ColorPickerUseColor(color));
          }
        },
        onStartSelectingCustomColor: () {
          setState(() => isCreatingCustomColor = true);
        },
      ),
    );
  }
}

class MainColorPicker extends StatelessWidget {
  const MainColorPicker({
    super.key,
    required this.config,
    required this.onSelectColor,
    required this.onStartSelectingCustomColor,
  });

  final ColorPickerConfig config;
  final void Function(AFColor) onSelectColor;
  final void Function() onStartSelectingCustomColor;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return BlocBuilder<ColorPickerBloc, ColorPickerState>(
      builder: (context, state) {
        return Padding(
          padding: EdgeInsets.symmetric(
            vertical: theme.spacing.s,
          ),
          child: SeparatedColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            separatorBuilder: () => AFDivider(spacing: theme.spacing.m),
            children: [
              if (config.showRecent && state.recentColors.isNotEmpty)
                RecentColorSection(
                  theme: theme,
                  colorType: config.colorType,
                  colors: state.recentColors,
                  onSelectColor: onSelectColor,
                ),
              BuiltinColorSection(
                theme: theme,
                config: config,
                onSelectColor: onSelectColor,
              ),
              if (config.showCustom)
                CustomColorSection(
                  theme: theme,
                  colorType: config.colorType,
                  colors: state.customColors,
                  onSelectColor: onSelectColor,
                  onStartCreatingCustomColor: onStartSelectingCustomColor,
                ),
            ],
          ),
        );
      },
    );
  }
}

class RecentColorSection extends StatelessWidget {
  const RecentColorSection({
    super.key,
    required this.theme,
    required this.colorType,
    required this.colors,
    required this.onSelectColor,
  });

  final AppFlowyThemeData theme;
  final ColorType colorType;
  final List<AFColor> colors;
  final void Function(AFColor) onSelectColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.m + theme.spacing.s,
        vertical: theme.spacing.s,
      ),
      child: Column(
        spacing: theme.spacing.m,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocaleKeys.colors_recent.tr(),
            style: theme.textStyle.caption.enhanced(
              color: theme.textColorScheme.tertiary,
            ),
          ),
          Row(
            spacing: theme.spacing.m,
            mainAxisSize: MainAxisSize.min,
            children: colors.map(
              (color) {
                return BlocBuilder<ColorPickerBloc, ColorPickerState>(
                  builder: (context, state) {
                    return ColorTile(
                      colorType: colorType,
                      color: color,
                      isSelected: state.selectedColor == color,
                      onSelect: () => onSelectColor(color),
                    );
                  },
                );
              },
            ).toList(),
          ),
        ],
      ),
    );
  }
}

class BuiltinColorSection extends StatelessWidget {
  const BuiltinColorSection({
    super.key,
    required this.theme,
    required this.config,
    required this.onSelectColor,
  });

  final AppFlowyThemeData theme;
  final ColorPickerConfig config;
  final void Function(AFColor) onSelectColor;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ColorPickerBloc, ColorPickerState>(
      builder: (context, state) {
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.m + theme.spacing.s,
            vertical: theme.spacing.s,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: theme.spacing.m,
            children: [
              Text(
                config.title,
                style: theme.textStyle.caption.enhanced(
                  color: theme.textColorScheme.tertiary,
                ),
              ),
              Wrap(
                spacing: theme.spacing.m,
                runSpacing: theme.spacing.m,
                children: [
                  if (config.defaultColor != null)
                    ColorTile(
                      colorType: config.colorType,
                      color: config.defaultColor!,
                      isSelected: state.selectedColor == config.defaultColor,
                      onSelect: () => onSelectColor(config.defaultColor!),
                    ),
                  for (final color in config.builtinColors)
                    ColorTile(
                      colorType: config.colorType,
                      color: color,
                      isSelected: state.selectedColor == color,
                      onSelect: () => onSelectColor(color),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class CustomColorSection extends StatelessWidget {
  const CustomColorSection({
    super.key,
    required this.theme,
    required this.colorType,
    required this.colors,
    required this.onSelectColor,
    required this.onStartCreatingCustomColor,
  });

  final AppFlowyThemeData theme;
  final ColorType colorType;
  final List<AFColor> colors;
  final void Function(AFColor) onSelectColor;
  final void Function() onStartCreatingCustomColor;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ColorPickerBloc, ColorPickerState>(
      builder: (context, state) {
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.m + theme.spacing.s,
            vertical: theme.spacing.s,
          ),
          child: Column(
            spacing: theme.spacing.m,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                LocaleKeys.colors_custom.tr(),
                style: theme.textStyle.caption.enhanced(
                  color: theme.textColorScheme.tertiary,
                ),
              ),
              Row(
                spacing: theme.spacing.m,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final color in state.customColors)
                    ColorTile(
                      colorType: colorType,
                      color: color,
                      isSelected: state.selectedColor == color,
                      onSelect: () => onSelectColor(color),
                    ),
                  CreateCustomColorTile(
                    onTap: onStartCreatingCustomColor,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
