import 'dart:async';

import 'package:appflowy/features/home_screen_widget/application/home_screen_widget_lifecycle_listener.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy_backend/log.dart';
import 'package:home_widget/home_widget.dart';
import 'package:universal_platform/universal_platform.dart';

@pragma("vm:entry-point")
FutureOr<void> homeScreenWidgetBackgroundCallback(Uri? data) async {
  return null;
}

// home screen widget app group id
// don't modify it, it used in the iOS and Android Native code
const String homeScreenWidgetGroupId = 'group.com.appflowy.widget';

class HomeScreenWidgetTask extends LaunchTask {
  const HomeScreenWidgetTask();

  @override
  LaunchTaskType get type => LaunchTaskType.dataProcessing;

  @override
  Future<void> initialize(LaunchContext context) async {
    await super.initialize(context);

    // only initialize on mobile platform
    if (!UniversalPlatform.isMobile) {
      return;
    }

    try {
      await HomeWidget.setAppGroupId(homeScreenWidgetGroupId);
      await HomeWidget.registerInteractivityCallback(
        homeScreenWidgetBackgroundCallback,
      );
      HomeWidget.widgetClicked.listen((event) {
        Log.info('Home screen widget clicked: $event');
      });

      context.getIt<HomeScreenWidgetLifecycleListener>();
    } catch (e) {
      Log.error('Failed to initialize home screen widget: $e');
    }
  }
}
