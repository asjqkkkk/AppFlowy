import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

sealed class AFColor extends Equatable {
  const AFColor(this.value);

  factory AFColor.fromValue(String value) {
    final color = value.tryToColor();
    if (color != null) {
      return CustomAFColor(value);
    } else {
      return BuiltinAFColor(value);
    }
  }

  final String value;

  Color? toColor(AppFlowyThemeData theme);

  Gradient? toGradient(AppFlowyThemeData theme);
}

final class BuiltinAFColor extends AFColor {
  const BuiltinAFColor(super.value);

  @override
  Color? toColor(AppFlowyThemeData theme) {
    return switch (value) {
      'text-default' => theme.textColorScheme.primary,
      'bg-default' => Colors.transparent,
      'text-color-1' => theme.paletteColorScheme.textColor1,
      'text-color-2' => theme.paletteColorScheme.textColor2,
      'text-color-3' => theme.paletteColorScheme.textColor3,
      'text-color-4' => theme.paletteColorScheme.textColor4,
      'text-color-5' => theme.paletteColorScheme.textColor5,
      'text-color-6' => theme.paletteColorScheme.textColor6,
      'text-color-7' => theme.paletteColorScheme.textColor7,
      'text-color-8' => theme.paletteColorScheme.textColor8,
      'text-color-9' => theme.paletteColorScheme.textColor9,
      'text-color-10' => theme.paletteColorScheme.textColor10,
      'text-color-11' => theme.paletteColorScheme.textColor11,
      'text-color-12' => theme.paletteColorScheme.textColor12,
      'text-color-13' => theme.paletteColorScheme.textColor13,
      'text-color-14' => theme.paletteColorScheme.textColor14,
      'text-color-15' => theme.paletteColorScheme.textColor15,
      'text-color-16' => theme.paletteColorScheme.textColor16,
      'text-color-17' => theme.paletteColorScheme.textColor17,
      'text-color-18' => theme.paletteColorScheme.textColor18,
      'text-color-19' => theme.paletteColorScheme.textColor19,
      'text-color-20' => theme.paletteColorScheme.textColor20,
      'bg-color-1' => theme.paletteColorScheme.bgColor1,
      'bg-color-2' => theme.paletteColorScheme.bgColor2,
      'bg-color-3' => theme.paletteColorScheme.bgColor3,
      'bg-color-4' => theme.paletteColorScheme.bgColor4,
      'bg-color-5' => theme.paletteColorScheme.bgColor5,
      'bg-color-6' => theme.paletteColorScheme.bgColor6,
      'bg-color-7' => theme.paletteColorScheme.bgColor7,
      'bg-color-8' => theme.paletteColorScheme.bgColor8,
      'bg-color-9' => theme.paletteColorScheme.bgColor9,
      'bg-color-10' => theme.paletteColorScheme.bgColor10,
      'bg-color-11' => theme.paletteColorScheme.bgColor11,
      'bg-color-12' => theme.paletteColorScheme.bgColor12,
      'bg-color-13' => theme.paletteColorScheme.bgColor13,
      'bg-color-14' => theme.paletteColorScheme.bgColor14,
      'bg-color-15' => theme.paletteColorScheme.bgColor15,
      'bg-color-16' => theme.paletteColorScheme.bgColor16,
      'bg-color-17' => theme.paletteColorScheme.bgColor17,
      'bg-color-18' => theme.paletteColorScheme.bgColor18,
      'bg-color-19' => theme.paletteColorScheme.bgColor19,
      'bg-color-20' => theme.paletteColorScheme.bgColor20,
      _ => null,
    };
  }

  @override
  Gradient? toGradient(AppFlowyThemeData theme) {
    final gradient = switch (value) {
      "gradient-color-dark-1" => [Color(0xFF6dd5ff), Color(0xFFd0a2ff)],
      "gradient-color-dark-2" => [Color(0xFFd0a2ff), Color(0xFFff84bf)],
      "gradient-color-dark-3" => [Color(0xFFff84bf), Color(0xFFffdd7b)],
      "gradient-color-dark-4" => [Color(0xFFffdd7b), Color(0xFF87ffab)],
      "gradient-color-dark-5" => [Color(0xFF89d7fe), Color(0xFF7a81ff)],
      "gradient-color-light-1" => [Color(0xFF00b5ff), Color(0xFF9225ff)],
      "gradient-color-light-2" => [Color(0xFF9327ff), Color(0xFFe7348a)],
      "gradient-color-light-3" => [Color(0xFFe3006d), Color(0xFFffbd00)],
      "gradient-color-light-4" => [Color(0xFFffbd00), Color(0xFF00bc38)],
      "gradient-color-light-5" => [Color(0xFF1cf8e3), Color(0xFF4b32fe)],
      _ => null,
    };

    if (gradient == null) {
      return null;
    }

    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: gradient,
    );
  }

  String? get i18n => switch (value) {
        'text-default' || 'bg-default' => LocaleKeys.colors_default.tr(),
        'text-color-1' || 'bg-color-1' => LocaleKeys.colors_rose.tr(),
        'text-color-2' || 'bg-color-2' => LocaleKeys.colors_papaya.tr(),
        'text-color-3' || 'bg-color-3' => LocaleKeys.colors_tangerine.tr(),
        'text-color-4' || 'bg-color-4' => LocaleKeys.colors_mango.tr(),
        'text-color-5' || 'bg-color-5' => LocaleKeys.colors_lemon.tr(),
        'text-color-6' || 'bg-color-6' => LocaleKeys.colors_olive.tr(),
        'text-color-7' || 'bg-color-7' => LocaleKeys.colors_lime.tr(),
        'text-color-8' || 'bg-color-8' => LocaleKeys.colors_grass.tr(),
        'text-color-9' || 'bg-color-9' => LocaleKeys.colors_forest.tr(),
        'text-color-10' || 'bg-color-10' => LocaleKeys.colors_jade.tr(),
        'text-color-11' || 'bg-color-11' => LocaleKeys.colors_aqua.tr(),
        'text-color-12' || 'bg-color-12' => LocaleKeys.colors_azure.tr(),
        'text-color-13' || 'bg-color-13' => LocaleKeys.colors_denim.tr(),
        'text-color-14' || 'bg-color-14' => LocaleKeys.colors_mauve.tr(),
        'text-color-15' || 'bg-color-15' => LocaleKeys.colors_lavender.tr(),
        'text-color-16' || 'bg-color-16' => LocaleKeys.colors_lilac.tr(),
        'text-color-17' || 'bg-color-17' => LocaleKeys.colors_mallow.tr(),
        'text-color-18' || 'bg-color-18' => LocaleKeys.colors_camellia.tr(),
        'text-color-19' || 'bg-color-19' => LocaleKeys.colors_smoke.tr(),
        'text-color-20' || 'bg-color-20' => LocaleKeys.colors_iron.tr(),
        _ => null,
      };

  @override
  List<Object?> get props => [value];
}

final class CustomAFColor extends AFColor {
  CustomAFColor(super.value);

  late final Color? _color = value.tryToColor();

  @override
  Color? toColor(AppFlowyThemeData theme) => _color;

  @override
  Gradient? toGradient(AppFlowyThemeData theme) => null;

  @override
  List<Object?> get props => [value];
}
