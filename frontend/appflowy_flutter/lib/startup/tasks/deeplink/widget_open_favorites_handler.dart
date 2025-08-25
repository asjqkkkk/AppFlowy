import 'dart:async';

import 'package:appflowy/startup/tasks/appflowy_cloud_task.dart';
import 'package:appflowy/startup/tasks/deeplink/deeplink_handler.dart';
import 'package:appflowy/workspace/presentation/home/menu/sidebar/workspace/workspace_notifier.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:universal_platform/universal_platform.dart';

// Widget open favorites deeplink example:
// appflowy-flutter://open-favorites/{workspace_id}
// only support on mobile
class WidgetOpenFavoritesHandler extends DeepLinkHandler<void> {
  static const openFavoritesHost = 'open-favorites';

  @override
  bool canHandle(Uri uri) {
    if (UniversalPlatform.isDesktop) {
      Log.info('WidgetOpenFavoritesHandler is not supported on desktop');
      return false;
    }

    final isOpenFavorites =
        uri.scheme == appflowyDeepLinkSchema && uri.host == openFavoritesHost;
    if (!isOpenFavorites) {
      Log.info('Unable to handle this deeplink: $uri');
      return false;
    }

    final pathSegments = uri.pathSegments;
    final canHandle = pathSegments.length == 1;
    return canHandle;
  }

  @override
  Future<FlowyResult<void, FlowyError>> handle({
    required Uri uri,
    required DeepLinkStateHandler onStateChange,
  }) async {
    final pathSegments = uri.pathSegments;
    final workspaceId = pathSegments.firstOrNull;

    if (workspaceId == null) {
      return FlowyResult.failure(
        FlowyError(
          msg:
              'Invalid URL format. Expected: appflowy-flutter://open-favorites/{workspace_id}',
        ),
      );
    }

    onStateChange(this, DeepLinkState.loading);

    Log.info(
      '[WidgetOpenFavoritesHandler] Opening favorites tab in workspace $workspaceId',
    );

    openWorkspaceNotifier.value = WorkspaceNotifyValue(
      workspaceId: workspaceId,
      openFavoritesTab: true,
    );

    onStateChange(this, DeepLinkState.finish);
    return FlowyResult.success(null);
  }
}
