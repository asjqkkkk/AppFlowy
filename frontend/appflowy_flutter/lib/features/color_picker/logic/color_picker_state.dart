import 'package:equatable/equatable.dart';

import '../data/models/af_color.dart';

class ColorPickerState extends Equatable {
  const ColorPickerState({
    this.selectedColor,
    this.recentColors = const [],
    this.customColors = const [],
    this.isCreatingCustomColor = false,
  });

  final AFColor? selectedColor;
  final List<AFColor> recentColors;
  final List<AFColor> customColors;
  final bool isCreatingCustomColor;

  ColorPickerState copyWith({
    AFColor? selectedColor,
    List<AFColor>? recentColors,
    List<AFColor>? customColors,
  }) {
    return ColorPickerState(
      selectedColor: selectedColor ?? this.selectedColor,
      recentColors: recentColors ?? this.recentColors,
      customColors: customColors ?? this.customColors,
    );
  }

  @override
  List<Object?> get props => [
        selectedColor,
        recentColors,
        customColors,
      ];
}
