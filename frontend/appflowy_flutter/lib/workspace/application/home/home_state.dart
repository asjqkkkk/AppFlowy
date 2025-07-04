import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/workspace.pb.dart';

class HomeState {
  factory HomeState.initial(WorkspaceLatestPB workspaceSetting) => HomeState(
        isLoading: false,
        workspaceSetting: workspaceSetting,
      );

  const HomeState({
    required this.isLoading,
    required this.workspaceSetting,
    this.latestView,
  });

  final bool isLoading;
  final WorkspaceLatestPB workspaceSetting;
  final ViewPB? latestView;

  HomeState copyWith({
    bool? isLoading,
    WorkspaceLatestPB? workspaceSetting,
    ViewPB? latestView,
  }) {
    return HomeState(
      isLoading: isLoading ?? this.isLoading,
      workspaceSetting: workspaceSetting ?? this.workspaceSetting,
      latestView: latestView ?? this.latestView,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HomeState &&
        other.isLoading == isLoading &&
        other.workspaceSetting == workspaceSetting &&
        other.latestView == latestView;
  }

  @override
  int get hashCode {
    return Object.hash(
      isLoading,
      workspaceSetting,
      latestView,
    );
  }

  @override
  String toString() {
    return 'HomeState(isLoading: $isLoading, workspaceSetting: $workspaceSetting, latestView: $latestView)';
  }
}
