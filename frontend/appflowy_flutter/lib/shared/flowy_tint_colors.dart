import 'package:appflowy/features/color_picker/color_picker.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

enum FlowyTint {
  tint1('appflowy_them_color_tint1'),
  tint2('appflowy_them_color_tint2'),
  tint3('appflowy_them_color_tint3'),
  tint4('appflowy_them_color_tint4'),
  tint5('appflowy_them_color_tint5'),
  tint6('appflowy_them_color_tint6'),
  tint7('appflowy_them_color_tint7'),
  tint8('appflowy_them_color_tint8'),
  tint9('appflowy_them_color_tint9'),
  tint10('appflowy_them_color_tint10'),
  tint11('appflowy_them_color_tint11'),
  tint12('appflowy_them_color_tint12'),
  tint13('appflowy_them_color_tint13'),
  tint14('appflowy_them_color_tint14');

  const FlowyTint(this.id);

  final String id;

  String toJson() => name;

  static FlowyTint fromJson(String json) {
    try {
      return FlowyTint.values.byName(json);
    } catch (_) {
      return FlowyTint.tint1;
    }
  }

  static FlowyTint? fromId(String id) {
    return values.firstWhereOrNull((element) => element.id == id);
  }

  Color color(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return toAFColor().toColor(theme) ?? Colors.transparent;
  }

  static FlowyTint? fromAFColor(AFColor color) {
    return switch (color.value) {
      'bg-color-14' => tint1,
      'bg-color-16' => tint2,
      'bg-color-18' => tint3,
      'bg-color-2' => tint4,
      'bg-color-4' => tint5,
      'bg-color-6' => tint6,
      'bg-color-8' => tint7,
      'bg-color-10' => tint8,
      'bg-color-12' => tint9,
      'bg-color-20' => tint10,
      'bg-color-15' => tint11,
      'bg-color-17' => tint12,
      'bg-color-1' => tint13,
      'bg-color-5' => tint14,
      _ => null,
    };
  }

  AFColor toAFColor() {
    return switch (this) {
      tint1 => BuiltinAFColor('bg-color-14'),
      tint2 => BuiltinAFColor('bg-color-16'),
      tint3 => BuiltinAFColor('bg-color-18'),
      tint4 => BuiltinAFColor('bg-color-2'),
      tint5 => BuiltinAFColor('bg-color-4'),
      tint6 => BuiltinAFColor('bg-color-6'),
      tint7 => BuiltinAFColor('bg-color-8'),
      tint8 => BuiltinAFColor('bg-color-10'),
      tint9 => BuiltinAFColor('bg-color-12'),
      tint10 => BuiltinAFColor('bg-color-20'),
      tint11 => BuiltinAFColor('bg-color-15'),
      tint12 => BuiltinAFColor('bg-color-17'),
      tint13 => BuiltinAFColor('bg-color-1'),
      tint14 => BuiltinAFColor('bg-color-5'),
    };
  }
}
