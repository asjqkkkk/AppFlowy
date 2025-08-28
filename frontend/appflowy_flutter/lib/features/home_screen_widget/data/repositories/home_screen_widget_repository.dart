import 'package:appflowy/features/home_screen_widget/data/models/home_screen_widget_data.dart';
import 'package:appflowy/features/home_screen_widget/data/models/home_screen_widget_item.dart';
import 'package:appflowy/features/home_screen_widget/data/models/home_screen_workspace_info.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';

// home screen widget communication key
// don't modify it, it used in the iOS and Android Native code
enum HomeScreenWidgetKeys {
  widgetData('appflowy_home_screen_widget_data'),
  workspaces('appflowy_home_screen_widget_data_workspaces'),
  iOSRecent('favorite_widget'),
  iOSFavorite('recent_widget'),
  iOSQuickAccess('quick_access_widget'),
  clearData('appflowy_home_screen_widget_clear_data');

  const HomeScreenWidgetKeys(
    this.key,
  );

  final String key;
}

String getWorkspaceWidgetDataKey(String workspaceId) {
  return '${HomeScreenWidgetKeys.widgetData.key}_$workspaceId';
}

String getWorkspacesWidgetDataKey() {
  return HomeScreenWidgetKeys.workspaces.key;
}

String getHomeScreenWidgetIconKey(String pageId) {
  return 'appflowy_home_screen_widget_data_${pageId}_icon';
}

abstract class HomeScreenWidgetRepository {
  Future<FlowyResult<List<HomeScreenWidgetItem>, FlowyError>> getRecentPages({
    required String workspaceId,
    int limit = 10,
  });

  Future<FlowyResult<List<HomeScreenWidgetItem>, FlowyError>> getFavoritePages({
    required String workspaceId,
    int limit = 10,
  });

  Future<FlowyResult<List<HomeScreenWorkspaceInfo>, FlowyError>>
      getAvailableWorkspaces();

  Future<FlowyResult<void, FlowyError>> clearWidgetData();

  Future<FlowyResult<void, FlowyError>> syncWorkspaceWidgetData(
    String workspaceId,
    HomeScreenWidgetData data,
  );

  Future<FlowyResult<void, FlowyError>> syncWorkspacesData(
    List<HomeScreenWorkspaceInfo> workspaces,
  );

  Future<bool> isAuthenticated();

  Future<String?> getAuthToken();

  Future<String?> getBaseURL();
}
