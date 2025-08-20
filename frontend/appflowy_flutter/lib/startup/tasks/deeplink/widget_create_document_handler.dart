import 'dart:async';

import 'package:appflowy/mobile/presentation/mobile_bottom_navigation_bar.dart';
import 'package:appflowy/startup/tasks/appflowy_cloud_task.dart';
import 'package:appflowy/startup/tasks/deeplink/deeplink_handler.dart';
import 'package:appflowy/workspace/presentation/home/menu/sidebar/workspace/workspace_notifier.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:universal_platform/universal_platform.dart';

// Widget create document deeplink example:
// appflowy-flutter://create-document/{workspace_id}
// only support on mobile
class WidgetCreateDocumentHandler extends DeepLinkHandler<void> {
  static const createDocumentHost = 'create-document';

  @override
  bool canHandle(Uri uri) {
    if (UniversalPlatform.isDesktop) {
      Log.info('WidgetCreateDocumentHandler is not supported on desktop');
      return false;
    }

    final isCreateDocument =
        uri.scheme == appflowyDeepLinkSchema && uri.host == createDocumentHost;
    if (!isCreateDocument) {
      Log.info(
        'Unable to handle this deeplink: $uri',
      );
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

    onStateChange(this, DeepLinkState.loading);

    openWorkspaceNotifier.value = WorkspaceNotifyValue(
      workspaceId: workspaceId,
      callback: (result) {
        if (result == true) {
          // delay 100ms to optimize the animtion effect
          Future.delayed(const Duration(milliseconds: 100), () {
            mobileCreateNewPageNotifier.value = ViewLayoutPB.Document;
          });
        }

        Log.info(
          'WidgetCreateDocumentHandler open workspace: $workspaceId, result: $result',
        );
      },
    );

    onStateChange(this, DeepLinkState.finish);
    return FlowyResult.success(null);
  }
}
