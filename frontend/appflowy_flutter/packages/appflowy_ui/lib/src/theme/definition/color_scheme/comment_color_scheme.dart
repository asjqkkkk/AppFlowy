import 'package:flutter/material.dart';

class AppFlowyCommentColorScheme {
  AppFlowyCommentColorScheme({
    required this.fill01,
    required this.fill01Select,
    required this.fill02,
    required this.fill02Select,
    required this.fill03,
    required this.fill03Select,
    required this.border01,
    required this.border01Select,
    required this.border02,
    required this.border02Select,
    required this.border03,
    required this.border03Select,
    required this.icon,
  });

  final Color fill01;
  final Color fill01Select;
  final Color fill02;
  final Color fill02Select;
  final Color fill03;
  final Color fill03Select;
  final Color border01;
  final Color border01Select;
  final Color border02;
  final Color border02Select;
  final Color border03;
  final Color border03Select;
  final Color icon;

  AppFlowyCommentColorScheme lerp(
    AppFlowyCommentColorScheme other,
    double t,
  ) {
    return AppFlowyCommentColorScheme(
      fill01: Color.lerp(fill01, other.fill01, t)!,
      fill01Select: Color.lerp(fill01Select, other.fill01Select, t)!,
      fill02: Color.lerp(fill02, other.fill02, t)!,
      fill02Select: Color.lerp(fill02Select, other.fill02Select, t)!,
      fill03: Color.lerp(fill03, other.fill03, t)!,
      fill03Select: Color.lerp(fill03Select, other.fill03Select, t)!,
      border01: Color.lerp(border01, other.border01, t)!,
      border01Select: Color.lerp(border01Select, other.border01Select, t)!,
      border02: Color.lerp(border02, other.border02, t)!,
      border02Select: Color.lerp(border02Select, other.border02Select, t)!,
      border03: Color.lerp(border03, other.border03, t)!,
      border03Select: Color.lerp(border03Select, other.border03Select, t)!,
      icon: Color.lerp(icon, other.icon, t)!,
    );
  }
}
