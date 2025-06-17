import 'dart:ui';

class AppFlowyOtherColorsColorScheme {
  const AppFlowyOtherColorsColorScheme({
    required this.textHighlight,
    required this.iconShared,
  });

  final Color textHighlight;
  final Color iconShared;

  AppFlowyOtherColorsColorScheme lerp(
    AppFlowyOtherColorsColorScheme other,
    double t,
  ) {
    return AppFlowyOtherColorsColorScheme(
      textHighlight: Color.lerp(textHighlight, other.textHighlight, t)!,
      iconShared: Color.lerp(iconShared, other.iconShared, t)!,
    );
  }
}
