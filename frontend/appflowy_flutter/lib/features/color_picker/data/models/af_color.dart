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
      'tag-fill-1-light' => theme.tagColorScheme.fill01Light,
      'tag-fill-2-light' => theme.tagColorScheme.fill02Light,
      'tag-fill-3-light' => theme.tagColorScheme.fill03Light,
      'tag-fill-4-light' => theme.tagColorScheme.fill04Light,
      'tag-fill-5-light' => theme.tagColorScheme.fill05Light,
      'tag-fill-6-light' => theme.tagColorScheme.fill06Light,
      'tag-fill-7-light' => theme.tagColorScheme.fill07Light,
      'tag-fill-8-light' => theme.tagColorScheme.fill08Light,
      'tag-fill-9-light' => theme.tagColorScheme.fill09Light,
      'tag-fill-10-light' => theme.tagColorScheme.fill10Light,
      'tag-fill-1-thick' => theme.tagColorScheme.fill01Thick,
      'tag-fill-2-thick' => theme.tagColorScheme.fill02Thick,
      'tag-fill-3-thick' => theme.tagColorScheme.fill03Thick,
      'tag-fill-4-thick' => theme.tagColorScheme.fill04Thick,
      'tag-fill-5-thick' => theme.tagColorScheme.fill05Thick,
      'tag-fill-6-thick' => theme.tagColorScheme.fill06Thick,
      'tag-fill-7-thick' => theme.tagColorScheme.fill07Thick,
      'tag-fill-8-thick' => theme.tagColorScheme.fill08Thick,
      'tag-fill-9-thick' => theme.tagColorScheme.fill09Thick,
      'tag-fill-10-thick' => theme.tagColorScheme.fill10Thick,
      'tag-text-1-light' => theme.tagColorScheme.text01Light,
      'tag-text-2-light' => theme.tagColorScheme.text02Light,
      'tag-text-3-light' => theme.tagColorScheme.text03Light,
      'tag-text-4-light' => theme.tagColorScheme.text04Light,
      'tag-text-5-light' => theme.tagColorScheme.text05Light,
      'tag-text-6-light' => theme.tagColorScheme.text06Light,
      'tag-text-7-light' => theme.tagColorScheme.text07Light,
      'tag-text-8-light' => theme.tagColorScheme.text08Light,
      'tag-text-9-light' => theme.tagColorScheme.text09Light,
      'tag-text-10-light' => theme.tagColorScheme.text10Light,
      'tag-text-1-thick' => theme.tagColorScheme.text01Thick,
      'tag-text-2-thick' => theme.tagColorScheme.text02Thick,
      'tag-text-3-thick' => theme.tagColorScheme.text03Thick,
      'tag-text-4-thick' => theme.tagColorScheme.text04Thick,
      'tag-text-5-thick' => theme.tagColorScheme.text05Thick,
      'tag-text-6-thick' => theme.tagColorScheme.text06Thick,
      'tag-text-7-thick' => theme.tagColorScheme.text07Thick,
      'tag-text-8-thick' => theme.tagColorScheme.text08Thick,
      'tag-text-9-thick' => theme.tagColorScheme.text09Thick,
      'tag-text-10-thick' => theme.tagColorScheme.text10Thick,
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
        'tag-fill-1-light' => LocaleKeys.colors_mauve.tr(),
        'tag-fill-2-light' => LocaleKeys.colors_lavender.tr(),
        'tag-fill-3-light' => LocaleKeys.colors_camellia.tr(),
        'tag-fill-4-light' => LocaleKeys.colors_papaya.tr(),
        'tag-fill-5-light' => LocaleKeys.colors_mango.tr(),
        'tag-fill-6-light' => LocaleKeys.colors_olive.tr(),
        'tag-fill-7-light' => LocaleKeys.colors_grass.tr(),
        'tag-fill-8-light' => LocaleKeys.colors_jade.tr(),
        'tag-fill-9-light' => LocaleKeys.colors_azure.tr(),
        'tag-fill-10-light' => LocaleKeys.colors_iron.tr(),
        'tag-fill-1-thick' => LocaleKeys.colors_mauveEmphasized.tr(),
        'tag-fill-2-thick' => LocaleKeys.colors_lavenderEmphasized.tr(),
        'tag-fill-3-thick' => LocaleKeys.colors_camelliaEmphasized.tr(),
        'tag-fill-4-thick' => LocaleKeys.colors_papayaEmphasized.tr(),
        'tag-fill-5-thick' => LocaleKeys.colors_mangoEmphasized.tr(),
        'tag-fill-6-thick' => LocaleKeys.colors_oliveEmphasized.tr(),
        'tag-fill-7-thick' => LocaleKeys.colors_grassEmphasized.tr(),
        'tag-fill-8-thick' => LocaleKeys.colors_jadeEmphasized.tr(),
        'tag-fill-9-thick' => LocaleKeys.colors_azureEmphasized.tr(),
        'tag-fill-10-thick' => LocaleKeys.colors_ironEmphasized.tr(),
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
