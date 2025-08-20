import 'package:flutter/material.dart';

extension NavigatorContext on BuildContext {
  void popToDesktopHome() {
    Navigator.of(this).popUntil((route) {
      if (route.settings.name == '/') {
        return true;
      }
      return false;
    });
  }

  void popToMobileHome() {
    Navigator.of(this).popUntil((route) {
      if (route.settings.name == '/home') {
        return true;
      }
      return false;
    });
  }
}
