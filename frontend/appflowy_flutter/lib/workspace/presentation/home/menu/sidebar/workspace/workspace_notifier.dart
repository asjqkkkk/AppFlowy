// Workaround for open workspace from invitation deep link
import 'package:flutter/material.dart';

ValueNotifier<WorkspaceNotifyValue?> openWorkspaceNotifier =
    ValueNotifier(null);

class WorkspaceNotifyValue {
  WorkspaceNotifyValue({
    this.workspaceId,
    this.email,
    this.initialViewId,
    this.openFavoritesTab = false,
    this.callback,
  });

  final String? workspaceId;
  final String? email;
  final String? initialViewId;
  final bool openFavoritesTab;
  final void Function(bool result)? callback;
}
