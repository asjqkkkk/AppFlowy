import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flutter/material.dart';

class SaturationAndValue extends StatelessWidget {
  const SaturationAndValue({
    super.key,
    required this.color,
    required this.onColorChanged,
  });

  final HSVColor color;
  final void Function(HSVColor) onColorChanged;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Container(
      height: 160,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(theme.spacing.m),
        border: Border.all(
          color: theme.borderColorScheme.primary,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) => handleUpdate(context, details.localPosition),
        onPanUpdate: (details) => handleUpdate(context, details.localPosition),
        child: CustomPaint(
          painter: HSVPalettePainter(color: color),
        ),
      ),
    );
  }

  void handleUpdate(BuildContext context, Offset localPosition) {
    final size = context.size;
    if (size == null) return;

    final dx = localPosition.dx.clamp(0.0, size.width);
    final dy = localPosition.dy.clamp(0.0, size.height);

    final saturation = dx / size.width;
    final value = 1.0 - (dy / size.height);

    final newColor = color.withSaturation(saturation).withValue(value);
    onColorChanged(newColor);
  }
}

class Hue extends StatelessWidget {
  const Hue({
    super.key,
    required this.color,
    required this.onColorChanged,
  });

  final HSVColor color;
  final void Function(HSVColor) onColorChanged;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Container(
      height: 24,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(theme.spacing.m),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) => handleUpdate(context, details.localPosition),
        onPanUpdate: (details) => handleUpdate(context, details.localPosition),
        child: CustomPaint(
          painter: HuePainter(color: color),
        ),
      ),
    );
  }

  void handleUpdate(BuildContext context, Offset localPosition) {
    final size = context.size;
    if (size == null) return;

    final dx = localPosition.dx.clamp(0.0, size.width);
    final hue = (dx / size.width) * 360.0;

    final newColor = color.withHue(hue);
    onColorChanged(newColor);
  }
}

class HSVPalettePainter extends CustomPainter {
  HSVPalettePainter({required this.color});

  final HSVColor color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final center = Offset(
      size.width * color.saturation,
      size.height * (1.0 - color.value),
    );

    final horizontalGradient = Paint()
      ..shader = LinearGradient(
        colors: [
          HSVColor.fromAHSV(1.0, color.hue, 0.0, 1.0).toColor(),
          HSVColor.fromAHSV(1.0, color.hue, 1.0, 1.0).toColor(),
        ],
      ).createShader(rect);

    final verticalGradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          HSVColor.fromAHSV(1.0, color.hue, 1.0, 0.0).toColor(),
          HSVColor.fromAHSV(0.0, color.hue, 1.0, 0.0).toColor(),
        ],
      ).createShader(rect);

    final innerCircle = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final outerCircle = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas
      ..drawRect(rect, horizontalGradient)
      ..drawRect(rect, verticalGradient)
      ..drawCircle(center, 10.5, innerCircle)
      ..drawCircle(center, 11.5, outerCircle);
  }

  @override
  bool shouldRepaint(covariant HSVPalettePainter oldDelegate) =>
      color != oldDelegate.color;
}

class HuePainter extends CustomPainter {
  HuePainter({required this.color});

  final HSVColor color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width * (color.hue / 360.0),
      size.height / 2,
    );

    final rect = Offset.zero & size;

    final gradient = Paint()
      ..shader = LinearGradient(
        colors: [
          const HSVColor.fromAHSV(1.0, 0.0, 1.0, 1.0).toColor(),
          const HSVColor.fromAHSV(1.0, 60.0, 1.0, 1.0).toColor(),
          const HSVColor.fromAHSV(1.0, 120.0, 1.0, 1.0).toColor(),
          const HSVColor.fromAHSV(1.0, 180.0, 1.0, 1.0).toColor(),
          const HSVColor.fromAHSV(1.0, 240.0, 1.0, 1.0).toColor(),
          const HSVColor.fromAHSV(1.0, 300.0, 1.0, 1.0).toColor(),
          const HSVColor.fromAHSV(1.0, 360.0, 1.0, 1.0).toColor(),
        ],
      ).createShader(rect);

    final innerCircle = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final outerCircle = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas
      ..drawRect(rect, gradient)
      ..drawCircle(center, 10.5, innerCircle)
      ..drawCircle(center, 11.5, outerCircle);
  }

  @override
  bool shouldRepaint(covariant HuePainter oldDelegate) =>
      color != oldDelegate.color;
}
