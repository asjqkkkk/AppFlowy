import 'dart:math' as math;

import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../data/models/af_color.dart';
import '../data/models/color_picker_config.dart';
import '../data/models/color_type.dart';
import 'color_tile.dart';

class MobileColorPicker extends StatefulWidget {
  const MobileColorPicker({
    super.key,
    required this.textColorConfig,
    required this.selectedTextColors,
    required this.onSelectTextColor,
    required this.backgroundColorConfig,
    required this.selectedBackgroundColors,
    required this.onSelectBackgroundColor,
  });

  final ColorPickerConfig textColorConfig;
  final List<AFColor> selectedTextColors;
  final void Function(AFColor? color) onSelectTextColor;

  final ColorPickerConfig backgroundColorConfig;
  final List<AFColor> selectedBackgroundColors;
  final void Function(AFColor? color) onSelectBackgroundColor;

  @override
  State<MobileColorPicker> createState() => _MobileColorPickerState();
}

class _MobileColorPickerState extends State<MobileColorPicker> {
  AFColor? selectedTextColor;
  AFColor? selectedBackgroundColor;

  @override
  void initState() {
    super.initState();
    selectedTextColor = switch (widget.selectedTextColors.length) {
      0 => widget.textColorConfig.defaultColor,
      1 => widget.selectedTextColors.first,
      _ => null,
    };
    selectedBackgroundColor = switch (widget.selectedBackgroundColors.length) {
      0 => widget.backgroundColorConfig.defaultColor,
      1 => widget.selectedBackgroundColors.first,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    final customTextColors =
        widget.selectedTextColors.whereType<CustomAFColor>().toList();
    final customBackgroundColors =
        widget.selectedBackgroundColors.whereType<CustomAFColor>().toList();

    return Padding(
      padding: EdgeInsets.all(theme.spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: theme.spacing.xxl,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextColorSection(
            selectedColor: selectedTextColor,
            config: widget.textColorConfig,
            onSelectColor: selectTextColor,
          ),
          BackgroundColorSection(
            selectedColor: selectedBackgroundColor,
            config: widget.backgroundColorConfig,
            onSelectColor: selectBackgroundColor,
          ),
          if (customTextColors.isNotEmpty || customBackgroundColors.isNotEmpty)
            MobileCustomColorSection(
              selectedTextColor: selectedTextColor,
              selectedBackgroundColor: selectedBackgroundColor,
              textColorsInSelection: customTextColors,
              bgColorsInSelection: customBackgroundColors,
              onSelectTextColor: selectTextColor,
              onSelectBackgroundColor: selectBackgroundColor,
            ),
        ],
      ),
    );
  }

  void selectTextColor(AFColor? color) {
    setState(
      () {
        if (color == widget.textColorConfig.defaultColor ||
            selectedTextColor == color) {
          selectedTextColor = widget.textColorConfig.defaultColor;
          widget.onSelectTextColor.call(null);
        } else {
          selectedTextColor = color;
          widget.onSelectTextColor.call(color);
        }
      },
    );
  }

  void selectBackgroundColor(AFColor? color) {
    setState(
      () {
        if (color == widget.backgroundColorConfig.defaultColor ||
            selectedBackgroundColor == color) {
          selectedBackgroundColor = widget.backgroundColorConfig.defaultColor;
          widget.onSelectBackgroundColor.call(null);
        } else {
          selectedBackgroundColor = color;
          widget.onSelectBackgroundColor.call(color);
        }
      },
    );
  }
}

class TextColorSection extends StatelessWidget {
  const TextColorSection({
    super.key,
    required this.selectedColor,
    required this.config,
    required this.onSelectColor,
  });

  final AFColor? selectedColor;
  final ColorPickerConfig config;
  final void Function(AFColor color) onSelectColor;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: theme.spacing.m,
      children: [
        Text(
          LocaleKeys.document_toolbar_textColor.tr(),
          style: theme.textStyle.caption.prominent(
            color: theme.textColorScheme.secondary,
          ),
        ),
        GridView.custom(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisExtent(
            crossAxisExtent: 48,
            mainAxisSpacing: theme.spacing.l,
            crossAxisSpacing: theme.spacing.l,
          ),
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          childrenDelegate: SliverChildBuilderDelegate(
            (context, index) {
              if (config.defaultColor != null && index == 0) {
                return MobileColorTile(
                  color: config.defaultColor,
                  colorType: ColorType.text,
                  isSelected: selectedColor == config.defaultColor,
                  onSelect: () => onSelectColor(config.defaultColor!),
                );
              }
              final color = config.builtinColors[index - 1];
              return MobileColorTile(
                colorType: ColorType.text,
                color: color,
                isSelected: selectedColor == color,
                onSelect: () => onSelectColor(color),
              );
            },
            childCount: config.builtinColors.length +
                (config.defaultColor != null ? 1 : 0),
          ),
        ),
      ],
    );
  }
}

class BackgroundColorSection extends StatelessWidget {
  const BackgroundColorSection({
    super.key,
    required this.selectedColor,
    required this.config,
    required this.onSelectColor,
  });

  final AFColor? selectedColor;
  final ColorPickerConfig config;
  final void Function(AFColor color) onSelectColor;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: theme.spacing.m,
      children: [
        Text(
          LocaleKeys.document_toolbar_backgroundColor.tr(),
          style: theme.textStyle.caption.prominent(
            color: theme.textColorScheme.secondary,
          ),
        ),
        GridView.custom(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisExtent(
            crossAxisExtent: 48,
            mainAxisSpacing: theme.spacing.l,
            crossAxisSpacing: theme.spacing.l,
          ),
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          childrenDelegate: SliverChildBuilderDelegate(
            (context, index) {
              if (config.defaultColor != null && index == 0) {
                return MobileColorTile(
                  color: config.defaultColor,
                  colorType: ColorType.background,
                  isSelected: selectedColor == config.defaultColor,
                  onSelect: () => onSelectColor(config.defaultColor!),
                );
              }
              final color = config.builtinColors[index - 1];
              return MobileColorTile(
                colorType: ColorType.background,
                color: color,
                isSelected: selectedColor == color,
                onSelect: () => onSelectColor(color),
              );
            },
            childCount: config.builtinColors.length +
                (config.defaultColor != null ? 1 : 0),
          ),
        ),
      ],
    );
  }
}

class MobileCustomColorSection extends StatelessWidget {
  const MobileCustomColorSection({
    super.key,
    required this.selectedTextColor,
    required this.selectedBackgroundColor,
    required this.textColorsInSelection,
    required this.bgColorsInSelection,
    required this.onSelectTextColor,
    required this.onSelectBackgroundColor,
  });

  final AFColor? selectedTextColor;
  final AFColor? selectedBackgroundColor;
  final List<AFColor> textColorsInSelection;
  final List<AFColor> bgColorsInSelection;
  final void Function(AFColor color) onSelectTextColor;
  final void Function(AFColor color) onSelectBackgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: theme.spacing.m,
      children: [
        Text(
          LocaleKeys.colors_custom.tr(),
          style: theme.textStyle.caption.prominent(
            color: theme.textColorScheme.secondary,
          ),
        ),
        GridView.custom(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisExtent(
            crossAxisExtent: 48,
            mainAxisSpacing: theme.spacing.l,
            crossAxisSpacing: theme.spacing.l,
          ),
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          childrenDelegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index < textColorsInSelection.length) {
                final color = textColorsInSelection[index];
                return MobileColorTile(
                  colorType: ColorType.text,
                  color: color,
                  isSelected: selectedTextColor == color,
                  onSelect: () => onSelectTextColor(color),
                );
              }

              final color =
                  bgColorsInSelection[index - textColorsInSelection.length];
              return MobileColorTile(
                colorType: ColorType.background,
                color: color,
                isSelected: selectedBackgroundColor == color,
                onSelect: () => onSelectBackgroundColor(color),
              );
            },
            childCount:
                textColorsInSelection.length + bgColorsInSelection.length,
          ),
        ),
      ],
    );
  }
}

class SliverGridDelegateWithFixedCrossAxisExtent extends SliverGridDelegate {
  /// Creates a delegate that makes grid layouts with tiles that have a fixed
  /// cross-axis extent.
  ///
  /// The [crossAxisExtent], [mainAxisExtent], [mainAxisSpacing],
  /// and [crossAxisSpacing] arguments must not be negative.
  /// The [childAspectRatio] argument must be greater than zero.
  const SliverGridDelegateWithFixedCrossAxisExtent({
    required this.crossAxisExtent,
    this.mainAxisSpacing = 0.0,
    this.crossAxisSpacing = 0.0,
    this.childAspectRatio = 1.0,
    this.mainAxisExtent,
  })  : assert(crossAxisExtent > 0),
        assert(mainAxisSpacing >= 0),
        assert(crossAxisSpacing >= 0),
        assert(childAspectRatio > 0),
        assert(mainAxisExtent == null || mainAxisExtent >= 0);

  /// The maximum extent of tiles in the cross axis.
  ///
  /// This delegate will select a cross-axis extent for the tiles that is as
  /// large as possible subject to the following conditions:
  ///
  ///  - The extent evenly divides the cross-axis extent of the grid.
  ///  - The extent is at most [crossAxisExtent].
  ///
  /// For example, if the grid is vertical, the grid is 500.0 pixels wide, and
  /// [crossAxisExtent] is 150.0, this delegate will create a grid with 4
  /// columns that are 125.0 pixels wide.
  final double crossAxisExtent;

  /// The number of logical pixels between each child along the main axis.
  final double mainAxisSpacing;

  /// The number of logical pixels between each child along the cross axis.
  final double crossAxisSpacing;

  /// The ratio of the cross-axis to the main-axis extent of each child.
  final double childAspectRatio;

  /// The extent of each tile in the main axis. If provided it would define the
  /// logical pixels taken by each tile in the main-axis.
  ///
  /// If null, [childAspectRatio] is used instead.
  final double? mainAxisExtent;

  bool _debugAssertIsValid(double crossAxisExtent) {
    assert(crossAxisExtent > 0.0);
    assert(crossAxisExtent > 0.0);
    assert(mainAxisSpacing >= 0.0);
    assert(crossAxisSpacing >= 0.0);
    assert(childAspectRatio > 0.0);
    return true;
  }

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    assert(_debugAssertIsValid(constraints.crossAxisExtent));

    final double allowedCrossAxisExtent = constraints.crossAxisExtent;
    final double unitExtent = crossAxisExtent + crossAxisSpacing;
    final double crossAxisCountDouble = allowedCrossAxisExtent / unitExtent;
    final double leftOver =
        allowedCrossAxisExtent - crossAxisCountDouble.floor() * unitExtent;
    int crossAxisCount = leftOver > allowedCrossAxisExtent
        ? crossAxisCountDouble.ceil()
        : crossAxisCountDouble.floor();
    // Ensure a minimum count of 1, can be zero and result in an infinite extent
    // below when the window size is 0.
    crossAxisCount = math.max(1, crossAxisCount);

    final double usableCrossAxisExtent = math.max(
      0.0,
      constraints.crossAxisExtent - crossAxisCount * crossAxisExtent,
    );
    final double childCrossAxisSpacing =
        usableCrossAxisExtent / (crossAxisCount - 1);
    final double childMainAxisExtent =
        mainAxisExtent ?? crossAxisExtent / childAspectRatio;
    return SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: childMainAxisExtent + mainAxisSpacing,
      crossAxisStride: crossAxisExtent + childCrossAxisSpacing,
      childMainAxisExtent: childMainAxisExtent,
      childCrossAxisExtent: crossAxisExtent,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(SliverGridDelegateWithFixedCrossAxisExtent oldDelegate) {
    return oldDelegate.crossAxisExtent != crossAxisExtent ||
        oldDelegate.mainAxisSpacing != mainAxisSpacing ||
        oldDelegate.crossAxisSpacing != crossAxisSpacing ||
        oldDelegate.childAspectRatio != childAspectRatio ||
        oldDelegate.mainAxisExtent != mainAxisExtent;
  }
}
