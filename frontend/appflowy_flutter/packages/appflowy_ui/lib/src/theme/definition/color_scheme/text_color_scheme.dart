import 'package:flutter/material.dart';

class AppFlowyTextColorScheme {
  const AppFlowyTextColorScheme({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.quaternary,
    required this.onFill,
    required this.action,
    required this.actionHover,
    required this.info,
    required this.infoHover,
    required this.infoOnFill,
    required this.success,
    required this.successHover,
    required this.successOnFill,
    required this.warning,
    required this.warningHover,
    required this.warningOnFill,
    required this.error,
    required this.errorHover,
    required this.errorOnFill,
    required this.featured,
    required this.featuredHover,
    required this.featuredOnFill,
  });

  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color quaternary;
  final Color onFill;
  final Color action;
  final Color actionHover;
  final Color info;
  final Color infoHover;
  final Color infoOnFill;
  final Color success;
  final Color successHover;
  final Color successOnFill;
  final Color warning;
  final Color warningHover;
  final Color warningOnFill;
  final Color error;
  final Color errorHover;
  final Color errorOnFill;
  final Color featured;
  final Color featuredHover;
  final Color featuredOnFill;

  AppFlowyTextColorScheme lerp(
    AppFlowyTextColorScheme other,
    double t,
  ) {
    return AppFlowyTextColorScheme(
      primary: Color.lerp(
        primary,
        other.primary,
        t,
      )!,
      secondary: Color.lerp(
        secondary,
        other.secondary,
        t,
      )!,
      tertiary: Color.lerp(
        tertiary,
        other.tertiary,
        t,
      )!,
      quaternary: Color.lerp(
        quaternary,
        other.quaternary,
        t,
      )!,
      onFill: Color.lerp(
        onFill,
        other.onFill,
        t,
      )!,
      action: Color.lerp(
        action,
        other.action,
        t,
      )!,
      actionHover: Color.lerp(
        actionHover,
        other.actionHover,
        t,
      )!,
      info: Color.lerp(
        info,
        other.info,
        t,
      )!,
      infoHover: Color.lerp(
        infoHover,
        other.infoHover,
        t,
      )!,
      infoOnFill: Color.lerp(
        infoOnFill,
        other.infoOnFill,
        t,
      )!,
      success: Color.lerp(
        success,
        other.success,
        t,
      )!,
      successHover: Color.lerp(
        successHover,
        other.successHover,
        t,
      )!,
      successOnFill: Color.lerp(
        successOnFill,
        other.successOnFill,
        t,
      )!,
      warning: Color.lerp(
        warning,
        other.warning,
        t,
      )!,
      warningHover: Color.lerp(
        warningHover,
        other.warningHover,
        t,
      )!,
      warningOnFill: Color.lerp(
        warningOnFill,
        other.warningOnFill,
        t,
      )!,
      error: Color.lerp(
        error,
        other.error,
        t,
      )!,
      errorHover: Color.lerp(
        errorHover,
        other.errorHover,
        t,
      )!,
      errorOnFill: Color.lerp(
        errorOnFill,
        other.errorOnFill,
        t,
      )!,
      featured: Color.lerp(
        featured,
        other.featured,
        t,
      )!,
      featuredHover: Color.lerp(
        featuredHover,
        other.featuredHover,
        t,
      )!,
      featuredOnFill: Color.lerp(
        featuredOnFill,
        other.featuredOnFill,
        t,
      )!,
    );
  }
}
