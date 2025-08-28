import 'dart:convert';

import 'package:appflowy/env/cloud_env.dart';
import 'package:appflowy/features/home_screen_widget/data/models/home_screen_widget_data.dart';
import 'package:appflowy/features/home_screen_widget/data/models/home_screen_widget_item.dart';
import 'package:appflowy/features/home_screen_widget/data/models/home_screen_workspace_info.dart';
import 'package:appflowy/features/home_screen_widget/data/repositories/home_screen_widget_repository.dart';
import 'package:appflowy/shared/af_user_profile_extension.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:fixnum/fixnum.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;

enum _WorkspaceEndpoint {
  recent('recent'),
  favorite('favorite');

  const _WorkspaceEndpoint(
    this.path,
  );

  final String path;
}

class HomeScreenWidgetRepositoryImpl implements HomeScreenWidgetRepository {
  @override
  Future<FlowyResult<List<HomeScreenWidgetItem>, FlowyError>> getRecentPages({
    required String workspaceId,
    int limit = 10,
  }) async {
    return _fetchPages(
      workspaceId: workspaceId,
      endpoint: _WorkspaceEndpoint.recent,
      limit: limit,
    );
  }

  @override
  Future<FlowyResult<List<HomeScreenWidgetItem>, FlowyError>> getFavoritePages({
    required String workspaceId,
    int limit = 10,
  }) async {
    return _fetchPages(
      workspaceId: workspaceId,
      endpoint: _WorkspaceEndpoint.favorite,
      limit: limit,
    );
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
        HomeWidget.updateWidget(
          iOSName: HomeScreenWidgetKeys.iOSQuickAccess.key,
        ),
      ]);

      return FlowyResult.success(null);
    } catch (e) {
      Log.error(
        'sync widget data for workspace $workspaceId: $e',
      );
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
      Log.error('sync workspaces data error: $e');
      return FlowyResult.failure(
        FlowyError()..msg = 'Failed to sync workspaces data: $e',
      );
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    final result = await UserEventGetUserProfile().send();
    return result.isSuccess;
  }

  @override
  Future<String?> getAuthToken() async {
    final result = await UserEventGetUserProfile().send();
    return result.fold(
      (profile) => profile.authToken,
      (error) => null,
    );
  }

  @override
  Future<String?> getBaseURL() async {
    return getAppFlowyCloudUrl();
  }

  @override
  Future<FlowyResult<List<HomeScreenWorkspaceInfo>, FlowyError>>
      getAvailableWorkspaces() async {
    final userResult = await UserEventGetUserProfile().send();
    final userEmail = userResult.fold(
      (profile) => profile.email,
      (error) => '',
    );

    return UserEventGetAllWorkspace().send().then((value) {
      return value.fold(
        (workspaces) => FlowyResult.success(
          workspaces.items
              .map(
                (e) => HomeScreenWorkspaceInfo(
                  id: e.workspaceId,
                  name: e.name,
                  icon: e.icon,
                  email: userEmail,
                ),
              )
              .toList(),
        ),
        (error) => FlowyResult.failure(error),
      );
    });
  }

  Future<FlowyResult<List<HomeScreenWidgetItem>, FlowyError>> _fetchPages({
    required String workspaceId,
    required _WorkspaceEndpoint endpoint,
    int limit = 10,
  }) async {
    try {
      final currentWorkspace = await FolderEventReadCurrentWorkspace().send();
      final currentWorkspaceId = currentWorkspace.fold(
        (workspace) => workspace.id,
        (error) => null,
      );

      if (currentWorkspaceId == workspaceId) {
        switch (endpoint) {
          case _WorkspaceEndpoint.recent:
            final payload = ReadRecentViewsPB(
              start: Int64(),
              limit: Int64(limit),
            );
            final recentViewsResult =
                await FolderEventReadRecentViews(payload).send();
            final recentViews = recentViewsResult.fold(
              (recentViews) => recentViews.items.map((e) => e.item).toList(),
              (error) => <ViewPB>[],
            );
            return FlowyResult.success(
              recentViews
                  .map(
                    (e) => HomeScreenWidgetItem.fromViewPB(e),
                  )
                  .toList(),
            );

          case _WorkspaceEndpoint.favorite:
            final favoriteResult = await FolderEventReadFavorites().send();
            final favoriteViews = favoriteResult.fold(
              (favoriteViews) =>
                  favoriteViews.items.map((e) => e.item).toList(),
              (error) => <ViewPB>[],
            );
            return FlowyResult.success(
              favoriteViews
                  .map(
                    (e) => HomeScreenWidgetItem.fromViewPB(e),
                  )
                  .toList(),
            );
        }
      }

      final authToken = await getAuthToken();

      if (authToken == null) {
        return FlowyResult.failure(
          FlowyError()..msg = 'Authentication required',
        );
      }

      final baseUrl = await getAppFlowyCloudUrl();
      final url =
          '$baseUrl/api/workspace/$workspaceId/${endpoint.path}?offset=0&limit=$limit';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'accept': 'application/json, text/plain, */',
          'authorization': 'Bearer $authToken',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(utf8.decode(response.bodyBytes));
        final items = HomeScreenWidgetItem.fromApiResponse(
          jsonData,
          limit: limit,
        );
        return FlowyResult.success(items);
      } else {
        Log.error(
          'fetch API(${endpoint.path}) error: ${response.statusCode} - ${response.body}',
        );
        return FlowyResult.failure(
          FlowyError()
            ..msg = 'Failed to fetch ${endpoint.path}: ${response.statusCode}',
        );
      }
    } catch (e) {
      Log.error(
        'fetch API(${endpoint.path}) error: $e',
      );
      return FlowyResult.failure(
        FlowyError()..msg = 'Failed to fetch ${endpoint.path}: $e',
      );
    }
  }
}
