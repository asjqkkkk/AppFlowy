import 'package:appflowy/features/home_screen_widget/application/home_screen_widget_data_sync_service.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy_backend/log.dart';
import 'package:flutter/widgets.dart';

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

    Log.info('App lifecycle state changed: $state');

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

  void _triggerWidgetSync(HomeScreenWidgetSyncReason reason) {
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
