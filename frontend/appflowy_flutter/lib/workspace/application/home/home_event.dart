import 'package:appflowy_backend/protobuf/flowy-folder/workspace.pb.dart';

/// Base class for all Home events
sealed class HomeEvent {
  const HomeEvent();

  /// Initialize the home bloc and start listening for workspace updates
  const factory HomeEvent.initial() = HomeInitialEvent;

  /// Show or hide loading state
  const factory HomeEvent.showLoading(bool isLoading) = HomeShowLoadingEvent;

  /// Update the workspace setting when received from listener
  const factory HomeEvent.didReceiveWorkspaceSetting(
    WorkspaceLatestPB setting,
  ) = HomeDidReceiveWorkspaceSettingEvent;

  /// Refresh the latest view
  const factory HomeEvent.refreshLatestView() = HomeRefreshLatestViewEvent;
}

class HomeInitialEvent extends HomeEvent {
  const HomeInitialEvent();
}

class HomeShowLoadingEvent extends HomeEvent {
  const HomeShowLoadingEvent(this.isLoading);

  final bool isLoading;
}

class HomeDidReceiveWorkspaceSettingEvent extends HomeEvent {
  const HomeDidReceiveWorkspaceSettingEvent(this.setting);

  final WorkspaceLatestPB setting;
}

class HomeRefreshLatestViewEvent extends HomeEvent {
  const HomeRefreshLatestViewEvent();
}
