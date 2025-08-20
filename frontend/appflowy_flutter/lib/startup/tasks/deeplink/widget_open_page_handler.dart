import 'dart:async';

import 'package:appflowy/startup/tasks/appflowy_cloud_task.dart';
import 'package:appflowy/startup/tasks/deeplink/deeplink_handler.dart';
import 'package:appflowy/workspace/presentation/home/menu/sidebar/workspace/workspace_notifier.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:universal_platform/universal_platform.dart';

// Widget open page deeplink example:
// appflowy-flutter://open-page/{workspace_id}/{page_id}
// only support on mobile
class WidgetOpenPageHandler extends DeepLinkHandler<void> {
  static const openPageHost = 'open-page';

  @override
  bool canHandle(Uri uri) {
    if (UniversalPlatform.isDesktop) {
      Log.info('WidgetOpenPageHandler is not supported on desktop');
      return false;
    }

    final isOpenPage =
        uri.scheme == appflowyDeepLinkSchema && uri.host == openPageHost;
    if (!isOpenPage) {
      Log.info('Unable to handle this deeplink: $uri');
      return false;
    }

    final pathSegments = uri.pathSegments;
    final canHandle = pathSegments.length == 2;
    return canHandle;
  }

  @override
  Future<FlowyResult<void, FlowyError>> handle({
    required Uri uri,
    required DeepLinkStateHandler onStateChange,
  }) async {
    final pathSegments = uri.pathSegments;
    final workspaceId = pathSegments.firstOrNull;
    final pageId = pathSegments.length > 1 ? pathSegments[1] : null;

    if (workspaceId == null || pageId == null) {
      return FlowyResult.failure(
        FlowyError(
          msg:
              'Invalid URL format. Expected: appflowy-flutter://open-page/{workspace_id}/{page_id}',
        ),
      );
    }

    onStateChange(this, DeepLinkState.loading);

    Log.info(
      '[WidgetOpenPageHandler] Opening page $pageId in workspace $workspaceId',
    );

    openWorkspaceNotifier.value = WorkspaceNotifyValue(
      workspaceId: workspaceId,
      initialViewId: pageId,
    );

    onStateChange(this, DeepLinkState.finish);
    return FlowyResult.success(null);
  }
}
