import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flutter/material.dart';

class WidgetTestWrapper extends StatelessWidget {
  const WidgetTestWrapper({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final themeBuilder = AppFlowyDefaultTheme();
    return AppFlowyTheme(
      data: brightness == Brightness.light
          ? themeBuilder.light()
          : themeBuilder.dark(),
      child: ToastificationWrapper(
        child: MaterialApp(
          home: Material(
            child: child,
          ),
        ),
      ),
    );
  }
}
