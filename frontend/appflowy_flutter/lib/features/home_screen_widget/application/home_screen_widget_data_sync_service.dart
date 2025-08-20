import 'package:appflowy/features/home_screen_widget/application/home_screen_widget_lifecycle_listener.dart';
import 'package:appflowy/features/home_screen_widget/data/models/home_screen_widget_data.dart';
import 'package:appflowy/features/home_screen_widget/data/models/home_screen_widget_item.dart';
import 'package:appflowy/features/home_screen_widget/data/models/home_screen_workspace_info.dart';
import 'package:appflowy/features/home_screen_widget/data/repositories/home_screen_widget_repository.dart';
import 'package:appflowy/features/home_screen_widget/data/repositories/home_screen_widget_repository_impl.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/header/emoji_icon_widget.dart';
import 'package:appflowy/shared/custom_image_cache_manager.dart';
import 'package:appflowy/shared/icon_emoji_picker/flowy_icon_emoji_picker.dart';
import 'package:appflowy/util/debounce.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy_backend/log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:home_widget/home_widget.dart';
import 'package:universal_platform/universal_platform.dart';

class HomeScreenWidgetDataSyncService {
  HomeScreenWidgetDataSyncService({
    HomeScreenWidgetRepository? repository,
  })  : _repository = repository ?? HomeScreenWidgetRepositoryImpl(),
        _debounce = Debounce(duration: const Duration());

  final HomeScreenWidgetRepository _repository;
  final Debounce _debounce;

  void dispose() {
    _debounce.dispose();
  }

  void syncWidgetData({
    required HomeScreenWidgetSyncReason reason,
  }) {
    _debounce.call(() => _performSync(reason: reason));
  }

  Future<void> _performSync({
    required HomeScreenWidgetSyncReason reason,
  }) async {
    if (!UniversalPlatform.isMobile) {
      return;
    }

    try {
      final isLoggedIn = await _repository.isAuthenticated();

      if (!isLoggedIn) {
        Log.info('User is not logged in, clearing widget data');
        await clearWidgetData();
      } else {
        Log.info('User is logged in, syncing widget data');
        await _syncLoggedInUserData(reason: reason);
      }
    } catch (e) {
      Log.error('Error syncing home screent widget data: $e');
    }
  }

  Future<void> _syncLoggedInUserData({
    required HomeScreenWidgetSyncReason reason,
  }) async {
    try {
      final workspacesResult = await _repository.getAvailableWorkspaces();
      final workspaces = workspacesResult.fold(
        (workspaceList) => workspaceList,
        (error) {
          Log.error(
            'Error fetching workspaces: $error',
          );
          return <HomeScreenWorkspaceInfo>[];
        },
      );

      // Sync the workspaces list for widget configuration
      if (workspaces.isNotEmpty) {
        Log.info('Syncing workspaces list for widget configuration');
        await _repository.syncWorkspacesData(workspaces);
      }

      await Future.wait(
        workspaces.map(
          (workspace) => _syncWorkspaceData(
            workspace: workspace,
            reason: reason,
          ),
        ),
      );
    } catch (e) {
      Log.error(
        'Error syncing logged in user data: $e',
      );
      rethrow;
    }
  }

  Future<void> _syncWorkspaceData({
    required HomeScreenWorkspaceInfo workspace,
    required HomeScreenWidgetSyncReason reason,
  }) async {
    try {
      final result = await Future.wait([
        _repository.getFavoritePages(workspaceId: workspace.id),
        _repository.getRecentPages(workspaceId: workspace.id),
      ]);

      final favoritesResult = result[0];
      final recentResult = result[1];

      final favorites = favoritesResult.fold(
        (favoritesList) => favoritesList,
        (error) => <HomeScreenWidgetItem>[],
      );

      final recent = recentResult.fold(
        (recentList) => recentList,
        (error) => <HomeScreenWidgetItem>[],
      );

      await _renderIconsForPages(
        pages: favorites,
        reason: reason,
      );
      await _renderIconsForPages(
        pages: recent,
        reason: reason,
      );

      final widgetData = HomeScreenWidgetData.loggedIn(
        currentWorkspaceId: workspace.id,
        workspaces: [workspace],
        favorites: favorites,
        recent: recent,
      );

      await _repository.syncWorkspaceWidgetData(workspace.id, widgetData);
    } catch (e) {
      Log.error(
        'Error syncing workspace ${workspace.id}: $e',
      );
      rethrow;
    }
  }

  Future<void> _renderIconsForPages({
    required List<HomeScreenWidgetItem> pages,
    required HomeScreenWidgetSyncReason reason,
  }) async {
    final futures = pages.map((page) async {
      try {
        await _renderIconForPage(
          page: page,
          reason: reason,
        );
      } catch (e) {
        Log.error('Failed to render icon for page ${page.id}: $e');
      }
    });

    await Future.wait(futures);
  }

  Future<void> _renderIconForPage({
    required HomeScreenWidgetItem page,
    required HomeScreenWidgetSyncReason reason,
  }) async {
    final cacheManager = CustomImageCacheManager();
    final key = getHomeScreenWidgetIconKey(page.id);

    try {
      final iconData = _parseIconData(page);

      final Widget widget;

      if (iconData == null) {
        widget = page.layout.defaultIcon(
          size: const Size.square(22.0),
          color: const Color(0xFF787E95),
        );
      } else {
        final file = await cacheManager.getFileFromCache(iconData.emoji);
        if (file != null && file.source == FileSource.Cache) {
          if (reason == HomeScreenWidgetSyncReason.appPaused ||
              reason == HomeScreenWidgetSyncReason.appInactive) {
            // there's a bug when the application is paused, the icon is not rendered
            final path = await HomeWidget.getWidgetData(key);
            if (path != null) {
              page.imageUrl = path;
              return;
            }
          }

          widget = Image.file(
            file.file,
            fit: BoxFit.cover,
            width: 22.0,
            height: 22.0,
          );
        } else {
          widget = RawEmojiIconWidget(
            emoji: iconData,
            emojiSize: 22.0,
            iconSize: 22.0,
          );
        }
      }

      final path = await HomeWidget.renderFlutterWidget(
        widget,
        key: key,
        logicalSize: const Size(32, 32),
        pixelRatio: 3,
      );

      if (path != null) {
        page.imageUrl = path;
      }
    } catch (e) {
      Log.error('Error rendering icon for page ${page.id}: $e');
    }
  }

  EmojiIconData? _parseIconData(HomeScreenWidgetItem page) {
    try {
      if (page.icon.isEmpty || page.icon == ' ') {
        return null;
      }

      switch (page.iconType) {
        case 0:
          return EmojiIconData.emoji(page.icon);
        case 1:
          return EmojiIconData(FlowyIconType.custom, page.icon);
        case 2:
          return EmojiIconData(FlowyIconType.icon, page.icon);
        default:
          return null;
      }
    } catch (e) {
      Log.error('Failed to parse icon data for page ${page.id}: $e');
      return null;
    }
  }

  Future<void> clearWidgetData() async {
    try {
      await _repository.clearWidgetData();
    } catch (e) {
      Log.error('Error clearing home screen widget data: $e');
    }
  }
}
