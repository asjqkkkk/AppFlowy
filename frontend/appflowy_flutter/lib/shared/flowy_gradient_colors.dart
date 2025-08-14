import 'package:appflowy/features/color_picker/color_picker.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

enum FlowyGradient {
  gradient1('appflowy_them_color_gradient1'),
  gradient2('appflowy_them_color_gradient2'),
  gradient3('appflowy_them_color_gradient3'),
  gradient4('appflowy_them_color_gradient4'),
  gradient5('appflowy_them_color_gradient5'),
  gradient6('appflowy_them_color_gradient6'),
  gradient7('appflowy_them_color_gradient7'),
  gradient8('appflowy_them_color_gradient8'),
  gradient9('appflowy_them_color_gradient9'),
  gradient10('appflowy_them_color_gradient10');

  const FlowyGradient(this.id);

  final String id;

  static FlowyGradient? fromId(String id) {
    return values.firstWhereOrNull((element) => element.id == id);
  }

  Gradient toGradient(BuildContext context) {
    return toAFColor().toGradient(AppFlowyTheme.of(context))!;
  }

  static FlowyGradient? fromAFColor(AFColor color) {
    return switch (color.value) {
      'gradient-color-dark-1' => gradient1,
      'gradient-color-dark-2' => gradient2,
      'gradient-color-dark-3' => gradient3,
      'gradient-color-dark-4' => gradient4,
      'gradient-color-dark-5' => gradient5,
      'gradient-color-light-1' => gradient6,
      'gradient-color-light-2' => gradient7,
      'gradient-color-light-3' => gradient8,
      'gradient-color-light-4' => gradient9,
      'gradient-color-light-5' => gradient10,
      _ => null,
    };
  }

  AFColor toAFColor() {
    return switch (this) {
      gradient1 => BuiltinAFColor('gradient-color-dark-1'),
      gradient2 => BuiltinAFColor('gradient-color-dark-2'),
      gradient3 => BuiltinAFColor('gradient-color-dark-3'),
      gradient4 => BuiltinAFColor('gradient-color-dark-4'),
      gradient5 => BuiltinAFColor('gradient-color-dark-5'),
      gradient6 => BuiltinAFColor('gradient-color-light-1'),
      gradient7 => BuiltinAFColor('gradient-color-light-2'),
      gradient8 => BuiltinAFColor('gradient-color-light-3'),
      gradient9 => BuiltinAFColor('gradient-color-light-4'),
      gradient10 => BuiltinAFColor('gradient-color-light-5'),
    };
  }
}
