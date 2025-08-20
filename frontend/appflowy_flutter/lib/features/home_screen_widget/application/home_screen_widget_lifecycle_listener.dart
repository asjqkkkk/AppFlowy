import 'package:appflowy/features/home_screen_widget/application/home_screen_widget_data_sync_service.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy_backend/log.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:universal_platform/universal_platform.dart';

enum HomeScreenWidgetSyncReason {
  appInitialization,
  appResumed,
  appPaused,
  appInactive,
}

class HomeScreenWidgetLifecycleListener with WidgetsBindingObserver {
  HomeScreenWidgetLifecycleListener._();
  static HomeScreenWidgetLifecycleListener? _instance;

  static HomeScreenWidgetLifecycleListener get instance {
    _instance ??= HomeScreenWidgetLifecycleListener._();
    return _instance!;
  }

  bool _isInitialized = false;

  void initialize() {
    if (_isInitialized) return;

    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;

    _triggerWidgetSync(HomeScreenWidgetSyncReason.appInitialization);
  }

  void dispose() {
    if (!_isInitialized) return;

    WidgetsBinding.instance.removeObserver(this);
    _isInitialized = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _triggerWidgetSync(HomeScreenWidgetSyncReason.appResumed);
        break;
      case AppLifecycleState.inactive:
        _triggerWidgetSync(HomeScreenWidgetSyncReason.appInactive);
        break;
      default:
        break;
    }
  }

  Future<void> _triggerWidgetSync(HomeScreenWidgetSyncReason reason) async {
    if (!UniversalPlatform.isMobile) {
      return;
    }

    final installedWidgets = await HomeWidget.getInstalledWidgets();
    if (installedWidgets.isEmpty) {
      Log.debug('No installed widgets found, skipping sync ($reason)');
      return;
    }

    try {
      Log.info('Trigger home screen widget sync ($reason)');
      getIt<HomeScreenWidgetDataSyncService>().syncWidgetData(
        reason: reason,
      );
    } catch (e) {
      Log.error('Failed to trigger home screen widget sync ($reason): $e');
    }
  }
}
