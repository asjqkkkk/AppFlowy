import 'dart:async';

import 'package:appflowy/startup/tasks/deeplink/deeplink_handler.dart';
import 'package:appflowy/workspace/presentation/home/menu/sidebar/workspace/workspace_notifier.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';


// open page callback deeplink example:
// appflowy-flutter://open-page?workspace_id=3694e181-2717-4b24-8177-e790e3663b1b&view_id=9625afb4-cb98-48d7-89be-5ba304df37adf3&email=tsuiyuenhong@gmail.com
class OpenPageDeepLinkHandler extends DeepLinkHandler<void> {
  static const openPageHost = 'open-page';
  static const openPageWorkspaceId = 'workspace_id';
  static const openPageViewId = 'view_id';
  static const openPageEmail = 'email';

  @override
  bool canHandle(Uri uri) {
    final isOpenPage = uri.host == openPageHost;
    if (!isOpenPage) {
      return false;
    }

    final containsWorkspaceId =
        uri.queryParameters.containsKey(openPageWorkspaceId);
    if (!containsWorkspaceId) {
      return false;
    }

    final containsViewId = uri.queryParameters.containsKey(openPageViewId);
    if (!containsViewId) {
      return false;
    }

    final containsEmail = uri.queryParameters.containsKey(openPageEmail);
    if (!containsEmail) {
      return false;
    }

    return true;
  }

  @override
  Future<FlowyResult<void, FlowyError>> handle({
    required Uri uri,
    required DeepLinkStateHandler onStateChange,
  }) async {
    final workspaceId = uri.queryParameters[openPageWorkspaceId];
    final viewId = uri.queryParameters[openPageViewId];
    final email = uri.queryParameters[openPageEmail];

    if (workspaceId == null) {
      return FlowyResult.failure(
        FlowyError(
          msg: 'Workspace ID is required',
        ),
      );
    }

    if (viewId == null) {
      return FlowyResult.failure(
        FlowyError(
          msg: 'View ID is required',
        ),
      );
    }

    if (email == null) {
      return FlowyResult.failure(
        FlowyError(
          msg: 'Email is required',
        ),
      );
    }

    openWorkspaceNotifier.value = WorkspaceNotifyValue(
      workspaceId: workspaceId,
      email: email,
      initialViewId: viewId,
    );

    return FlowyResult.success(null);
  }
}
