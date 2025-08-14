import 'package:flutter/material.dart';

@immutable
class AFThemeExtension extends ThemeExtension<AFThemeExtension> {
  static AFThemeExtension of(BuildContext context) =>
      Theme.of(context).extension<AFThemeExtension>()!;

  static AFThemeExtension? maybeOf(BuildContext context) =>
      Theme.of(context).extension<AFThemeExtension>();

  const AFThemeExtension({
    required this.warning,
    required this.success,
    required this.greyHover,
    required this.greySelect,
    required this.lightGreyHover,
    required this.toggleOffFill,
    required this.textColor,
    required this.secondaryTextColor,
    required this.strongText,
    required this.calloutBGColor,
    required this.tableCellBGColor,
    required this.calendarWeekendBGColor,
    required this.code,
    required this.callout,
    required this.caption,
    required this.progressBarBGColor,
    required this.toggleButtonBGColor,
    required this.gridRowCountColor,
    required this.background,
    required this.onBackground,
    required this.borderColor,
    required this.scrollbarColor,
    required this.scrollbarHoverColor,
    required this.toolbarHoverColor,
    required this.lightIconColor,
  });

  final Color? warning;
  final Color? success;

  final Color textColor;
  final Color secondaryTextColor;
  final Color strongText;
  final Color greyHover;
  final Color greySelect;
  final Color lightGreyHover;
  final Color toggleOffFill;
  final Color progressBarBGColor;
  final Color toggleButtonBGColor;
  final Color calloutBGColor;
  final Color tableCellBGColor;
  final Color calendarWeekendBGColor;
  final Color gridRowCountColor;

  final TextStyle code;
  final TextStyle callout;
  final TextStyle caption;

  final Color background;
  final Color onBackground;

  /// The color of the border of the widget.
  ///
  /// This is used in the divider, outline border, etc.
  final Color borderColor;

  final Color scrollbarColor;
  final Color scrollbarHoverColor;

  final Color toolbarHoverColor;
  final Color lightIconColor;

  @override
  AFThemeExtension copyWith({
    Color? warning,
    Color? success,
    Color? textColor,
    Color? secondaryTextColor,
    Color? strongText,
    Color? calloutBGColor,
    Color? tableCellBGColor,
    Color? greyHover,
    Color? greySelect,
    Color? lightGreyHover,
    Color? toggleOffFill,
    Color? progressBarBGColor,
    Color? toggleButtonBGColor,
    Color? calendarWeekendBGColor,
    Color? gridRowCountColor,
    TextStyle? code,
    TextStyle? callout,
    TextStyle? caption,
    Color? background,
    Color? onBackground,
    Color? borderColor,
    Color? scrollbarColor,
    Color? scrollbarHoverColor,
    Color? lightIconColor,
    Color? toolbarHoverColor,
  }) =>
      AFThemeExtension(
        warning: warning ?? this.warning,
        success: success ?? this.success,
        textColor: textColor ?? this.textColor,
        secondaryTextColor: secondaryTextColor ?? this.secondaryTextColor,
        strongText: strongText ?? this.strongText,
        calloutBGColor: calloutBGColor ?? this.calloutBGColor,
        tableCellBGColor: tableCellBGColor ?? this.tableCellBGColor,
        greyHover: greyHover ?? this.greyHover,
        greySelect: greySelect ?? this.greySelect,
        lightGreyHover: lightGreyHover ?? this.lightGreyHover,
        toggleOffFill: toggleOffFill ?? this.toggleOffFill,
        progressBarBGColor: progressBarBGColor ?? this.progressBarBGColor,
        toggleButtonBGColor: toggleButtonBGColor ?? this.toggleButtonBGColor,
        calendarWeekendBGColor:
            calendarWeekendBGColor ?? this.calendarWeekendBGColor,
        gridRowCountColor: gridRowCountColor ?? this.gridRowCountColor,
        code: code ?? this.code,
        callout: callout ?? this.callout,
        caption: caption ?? this.caption,
        onBackground: onBackground ?? this.onBackground,
        background: background ?? this.background,
        borderColor: borderColor ?? this.borderColor,
        scrollbarColor: scrollbarColor ?? this.scrollbarColor,
        scrollbarHoverColor: scrollbarHoverColor ?? this.scrollbarHoverColor,
        lightIconColor: lightIconColor ?? this.lightIconColor,
        toolbarHoverColor: toolbarHoverColor ?? this.toolbarHoverColor,
      );

  @override
  ThemeExtension<AFThemeExtension> lerp(
      ThemeExtension<AFThemeExtension>? other, double t) {
    if (other is! AFThemeExtension) {
      return this;
    }
    return AFThemeExtension(
      warning: Color.lerp(warning, other.warning, t),
      success: Color.lerp(success, other.success, t),
      textColor: Color.lerp(textColor, other.textColor, t)!,
      secondaryTextColor: Color.lerp(
        secondaryTextColor,
        other.secondaryTextColor,
        t,
      )!,
      strongText: Color.lerp(
        strongText,
        other.strongText,
        t,
      )!,
      calloutBGColor: Color.lerp(calloutBGColor, other.calloutBGColor, t)!,
      tableCellBGColor:
          Color.lerp(tableCellBGColor, other.tableCellBGColor, t)!,
      greyHover: Color.lerp(greyHover, other.greyHover, t)!,
      greySelect: Color.lerp(greySelect, other.greySelect, t)!,
      lightGreyHover: Color.lerp(lightGreyHover, other.lightGreyHover, t)!,
      toggleOffFill: Color.lerp(toggleOffFill, other.toggleOffFill, t)!,
      progressBarBGColor:
          Color.lerp(progressBarBGColor, other.progressBarBGColor, t)!,
      toggleButtonBGColor:
          Color.lerp(toggleButtonBGColor, other.toggleButtonBGColor, t)!,
      calendarWeekendBGColor:
          Color.lerp(calendarWeekendBGColor, other.calendarWeekendBGColor, t)!,
      gridRowCountColor:
          Color.lerp(gridRowCountColor, other.gridRowCountColor, t)!,
      code: other.code,
      callout: other.callout,
      caption: other.caption,
      onBackground: Color.lerp(onBackground, other.onBackground, t)!,
      background: Color.lerp(background, other.background, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      scrollbarColor: Color.lerp(scrollbarColor, other.scrollbarColor, t)!,
      scrollbarHoverColor:
          Color.lerp(scrollbarHoverColor, other.scrollbarHoverColor, t)!,
      lightIconColor: Color.lerp(lightIconColor, other.lightIconColor, t)!,
      toolbarHoverColor:
          Color.lerp(toolbarHoverColor, other.toolbarHoverColor, t)!,
    );
  }
}
