import 'dart:ui';

class AppFlowyOtherColorsColorScheme {
  const AppFlowyOtherColorsColorScheme({
    required this.textHighlight,
    required this.iconShared,
    required this.textEvent,
    required this.filledEvent,
    required this.filledToday,
  });

  final Color textHighlight;
  final Color iconShared;
  final Color textEvent;
  final Color filledEvent;
  final Color filledToday;

  AppFlowyOtherColorsColorScheme lerp(
    AppFlowyOtherColorsColorScheme other,
    double t,
  ) {
    return AppFlowyOtherColorsColorScheme(
      textHighlight: Color.lerp(textHighlight, other.textHighlight, t)!,
      iconShared: Color.lerp(iconShared, other.iconShared, t)!,
      textEvent: Color.lerp(textEvent, other.textEvent, t)!,
      filledEvent: Color.lerp(filledEvent, other.filledEvent, t)!,
      filledToday: Color.lerp(filledToday, other.filledToday, t)!,
    );
  }
}
