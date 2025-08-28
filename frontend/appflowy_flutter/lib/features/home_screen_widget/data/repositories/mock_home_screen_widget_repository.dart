import 'dart:convert';

import 'package:appflowy/features/home_screen_widget/data/models/home_screen_widget_data.dart';
import 'package:appflowy/features/home_screen_widget/data/models/home_screen_widget_item.dart';
import 'package:appflowy/features/home_screen_widget/data/models/home_screen_workspace_info.dart';
import 'package:appflowy/features/home_screen_widget/data/repositories/home_screen_widget_repository.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:home_widget/home_widget.dart';

class MockHomeScreenWidgetRepository implements HomeScreenWidgetRepository {
  MockHomeScreenWidgetRepository({this.simulateLoggedIn = false});

  final bool simulateLoggedIn;

  @override
  Future<FlowyResult<List<HomeScreenWidgetItem>, FlowyError>> getRecentPages({
    required String workspaceId,
    int limit = 10,
  }) async {
    final items = [
      HomeScreenWidgetItem(
        id: 'recent_1',
        title: 'Meeting Notes',
        icon: '📝',
        layout: ViewLayoutPB.Document,
      ),
      HomeScreenWidgetItem(
        id: 'recent_2',
        title: 'Project Roadmap',
        icon: '🗺️',
        layout: ViewLayoutPB.Board,
      ),
      HomeScreenWidgetItem(
        id: 'recent_3',
        title: 'Task List',
        icon: '✅',
        layout: ViewLayoutPB.Grid,
      ),
      HomeScreenWidgetItem(
        id: 'recent_4',
        title: 'Design Specs',
        icon: '🎨',
        layout: ViewLayoutPB.Document,
      ),
      HomeScreenWidgetItem(
        id: 'recent_5',
        title: 'Budget Tracker',
        icon: '💰',
        layout: ViewLayoutPB.Grid,
      ),
      HomeScreenWidgetItem(
        id: 'recent_6',
        title: 'Team Calendar',
        icon: '📅',
        layout: ViewLayoutPB.Calendar,
      ),
      HomeScreenWidgetItem(
        id: 'recent_7',
        title: 'Product Backlog',
        icon: '📋',
        layout: ViewLayoutPB.Board,
      ),
      HomeScreenWidgetItem(
        id: 'recent_8',
        title: 'Research Notes',
        icon: '🔬',
        layout: ViewLayoutPB.Document,
      ),
    ].take(limit).toList();

    return FlowyResult.success(items);
  }

  @override
  Future<FlowyResult<List<HomeScreenWidgetItem>, FlowyError>> getFavoritePages({
    required String workspaceId,
    int limit = 10,
  }) async {
    final items = [
      HomeScreenWidgetItem(
        id: 'fav_1',
        title: 'Quick Notes',
        icon: '⚡',
        layout: ViewLayoutPB.Document,
      ),
      HomeScreenWidgetItem(
        id: 'fav_2',
        title: 'Important Links',
        icon: '🔗',
        layout: ViewLayoutPB.Document,
      ),
      HomeScreenWidgetItem(
        id: 'fav_3',
        title: 'Team Directory',
        icon: '📖',
        layout: ViewLayoutPB.Grid,
      ),
      HomeScreenWidgetItem(
        id: 'fav_4',
        title: 'Weekly Report',
        icon: '📊',
        layout: ViewLayoutPB.Document,
      ),
      HomeScreenWidgetItem(
        id: 'fav_5',
        title: 'Sprint Board',
        icon: '🏃',
        layout: ViewLayoutPB.Board,
      ),
      HomeScreenWidgetItem(
        id: 'fav_6',
        title: 'Knowledge Base',
        icon: '📚',
        layout: ViewLayoutPB.Document,
      ),
    ].take(limit).toList();

    return FlowyResult.success(items);
  }

  @override
  Future<FlowyResult<void, FlowyError>> clearWidgetData() async {
    try {
      final emptyData = HomeScreenWidgetData.notLoggedIn();

      await HomeWidget.saveWidgetData<String>(
        HomeScreenWidgetKeys.clearData.key,
        jsonEncode(emptyData.toJson()),
      );

      await Future.wait([
        HomeWidget.updateWidget(iOSName: HomeScreenWidgetKeys.iOSFavorite.key),
        HomeWidget.updateWidget(iOSName: HomeScreenWidgetKeys.iOSRecent.key),
      ]);

      return FlowyResult.success(null);
    } catch (e) {
      return FlowyResult.failure(
        FlowyError()..msg = 'Failed to clear widget data: $e',
      );
    }
  }

  @override
  Future<FlowyResult<void, FlowyError>> syncWorkspaceWidgetData(
    String workspaceId,
    HomeScreenWidgetData data,
  ) async {
    try {
      final workspaceKey = getWorkspaceWidgetDataKey(workspaceId);

      await HomeWidget.saveWidgetData<String>(
        workspaceKey,
        jsonEncode(data.toJson()),
      );

      await Future.wait([
        HomeWidget.updateWidget(iOSName: HomeScreenWidgetKeys.iOSFavorite.key),
        HomeWidget.updateWidget(iOSName: HomeScreenWidgetKeys.iOSRecent.key),
      ]);

      return FlowyResult.success(null);
    } catch (e) {
      return FlowyResult.failure(
        FlowyError()
          ..msg = 'Failed to sync widget data for workspace $workspaceId: $e',
      );
    }
  }

  @override
  Future<FlowyResult<void, FlowyError>> syncWorkspacesData(
    List<HomeScreenWorkspaceInfo> workspaces,
  ) async {
    try {
      final workspacesKey = getWorkspacesWidgetDataKey();

      final workspacesData = {
        'workspaces': workspaces.map((w) => w.toJson()).toList(),
      };

      await HomeWidget.saveWidgetData<String>(
        workspacesKey,
        jsonEncode(workspacesData),
      );

      return FlowyResult.success(null);
    } catch (e) {
      return FlowyResult.failure(
        FlowyError()..msg = 'Failed to sync workspaces data: $e',
      );
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    return simulateLoggedIn;
  }

  @override
  Future<FlowyResult<List<HomeScreenWorkspaceInfo>, FlowyError>>
      getAvailableWorkspaces() async {
    final workspaces = [
      const HomeScreenWorkspaceInfo(
        id: 'workspace_1',
        name: 'Personal Workspace',
        icon: '🏠',
        email: 'user@example.com',
      ),
      const HomeScreenWorkspaceInfo(
        id: 'workspace_2',
        name: 'Team Workspace',
        icon: '👥',
        email: 'user@example.com',
      ),
      const HomeScreenWorkspaceInfo(
        id: 'workspace_3',
        name: 'Project Alpha',
        icon: '🚀',
        email: 'user@example.com',
      ),
    ];

    return FlowyResult.success(workspaces);
  }

  @override
  Future<String?> getAuthToken() async {
    return null;
  }

  @override
  Future<String?> getBaseURL() async {
    return 'https://beta.appflowy.cloud';
  }
}
