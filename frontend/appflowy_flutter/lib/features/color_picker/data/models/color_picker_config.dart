import 'af_color.dart';
import 'color_type.dart';

final class ColorPickerConfig {
  ColorPickerConfig({
    required this.key,
    this.innerKey = 'shared',
    required this.colorType,
    required this.title,
    required this.builtinColors,
    required this.maxColorLimit,
    this.defaultColor,
    this.showRecent = true,
    this.showCustom = true,
  });

  final String title;
  final ColorType colorType;
  final String key;
  final String innerKey;
  final List<BuiltinAFColor> builtinColors;
  final int maxColorLimit;
  final AFColor? defaultColor;
  final bool showRecent;
  final bool showCustom;
}
