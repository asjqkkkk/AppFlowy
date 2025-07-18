import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

import '../data/models/af_color.dart';
import '../data/models/color_type.dart';

class ColorTile extends StatefulWidget {
  const ColorTile({
    super.key,
    required this.colorType,
    required this.color,
    required this.isSelected,
    required this.onSelect,
  });

  final AFColor? color;
  final ColorType colorType;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  State<ColorTile> createState() => _ColorTileState();
}

class _ColorTileState extends State<ColorTile> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    final tooltip = switch (widget.color) {
      final BuiltinAFColor color => color.i18n,
      _ => null,
    };

    return FlowyTooltip(
      message: tooltip,
      preferBelow: false,
      child: GestureDetector(
        onTap: widget.onSelect,
        behavior: HitTestBehavior.opaque,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: Container(
            width: 28.0,
            height: 28.0,
            alignment: Alignment.center,
            decoration: _decoration(theme),
            child: child(theme),
          ),
        ),
      ),
    );
  }

  BoxDecoration _decoration(AppFlowyThemeData theme) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(6.0),
      border: widget.isSelected
          ? Border.all(
              color: theme.borderColorScheme.themeThick,
              width: 2.0,
            )
          : Border.all(
              color: isHovered
                  ? theme.borderColorScheme.primaryHover
                  : theme.borderColorScheme.primary,
            ),
    );
  }

  Widget? child(AppFlowyThemeData theme) {
    final rgbColor = widget.color?.toColor(theme);

    return switch (widget.colorType) {
      ColorType.text => Text(
          'A',
          style: TextStyle(
            inherit: false,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.0,
            color: rgbColor,
          ),
        ),
      ColorType.background when widget.isSelected => Container(
          constraints: BoxConstraints.tight(Size.square(20)),
          decoration: BoxDecoration(
            color: rgbColor,
            borderRadius: BorderRadius.circular(3.0),
          ),
        ),
      ColorType.background => Container(
          constraints: BoxConstraints.tight(Size.square(24)),
          decoration: BoxDecoration(
            color: rgbColor,
            borderRadius: BorderRadius.circular(4.0),
          ),
        ),
    };
  }
}

class MobileColorTile extends StatelessWidget {
  const MobileColorTile({
    super.key,
    required this.colorType,
    required this.color,
    required this.isSelected,
    required this.onSelect,
  });

  final AFColor? color;
  final ColorType colorType;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return GestureDetector(
      onTap: onSelect,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: BoxConstraints.tight(Size.square(48)),
        padding: EdgeInsets.zero,
        alignment: Alignment.center,
        decoration: _decoration(theme),
        child: _child(theme),
      ),
    );
  }

  BoxDecoration _decoration(AppFlowyThemeData theme) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(theme.spacing.m),
      border: isSelected
          ? Border.all(
              color: theme.borderColorScheme.themeThick,
              width: 2.0,
            )
          : Border.all(
              color: theme.borderColorScheme.primary,
            ),
    );
  }

  Widget? _child(AppFlowyThemeData theme) {
    final rgbColor = color?.toColor(theme);

    return switch (colorType) {
      ColorType.text => Text(
          'A',
          style: TextStyle(
            inherit: false,
            fontSize: 24.0,
            height: 32.0 / 24.0,
            color: rgbColor,
          ),
        ),
      ColorType.background => Container(
          constraints: BoxConstraints.tight(Size.square(40)),
          decoration: BoxDecoration(
            color: rgbColor,
            borderRadius: BorderRadius.circular(5.0),
          ),
        ),
    };
  }
}

class CreateCustomColorTile extends StatefulWidget {
  const CreateCustomColorTile({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<CreateCustomColorTile> createState() => _CreateCustomColorTileState();
}

class _CreateCustomColorTileState extends State<CreateCustomColorTile> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => isHovered = true),
        onExit: (_) => setState(() => isHovered = false),
        child: Container(
          width: 28.0,
          height: 28.0,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6.0),
            border: Border.all(
              color: isHovered
                  ? theme.borderColorScheme.primaryHover
                  : theme.borderColorScheme.primary,
            ),
          ),
          alignment: Alignment.center,
          child: FlowySvg(
            FlowySvgs.add_m,
            size: Size.square(20),
            color: theme.iconColorScheme.tertiary,
          ),
        ),
      ),
    );
  }
}
