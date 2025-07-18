import '../data/models/af_color.dart';

sealed class ColorPickerEvent {
  const ColorPickerEvent();
}

class ColorPickerInitial extends ColorPickerEvent {
  const ColorPickerInitial(this.selectedColors);

  final List<AFColor> selectedColors;
}

class ColorPickerUseColor extends ColorPickerEvent {
  const ColorPickerUseColor(this.color);

  final AFColor color;
}

class ColorPickerUseDefaultColor extends ColorPickerEvent {
  const ColorPickerUseDefaultColor();
}

class ColorPickerCreateCustomColor extends ColorPickerEvent {
  const ColorPickerCreateCustomColor(this.color);

  final AFColor color;
}
