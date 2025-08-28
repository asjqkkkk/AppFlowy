import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';

class HomeState {
  factory HomeState.initial(String workspaceId) => HomeState(
        isLoading: false,
        workspaceId: workspaceId,
      );

  const HomeState({
    required this.isLoading,
    required this.workspaceId,
    this.latestView,
    this.pageError,
  });

  final bool isLoading;
  final String workspaceId;
  final ViewPB? latestView;
  final FlowyError? pageError;

  HomeState copyWith({
    bool? isLoading,
    String? workspaceId,
    ViewPB? latestView,
    FlowyError? pageError,
    bool clearLatestView = false,
    bool clearPageError = false,
  }) {
    return HomeState(
      isLoading: isLoading ?? this.isLoading,
      workspaceId: workspaceId ?? this.workspaceId,
      latestView: clearLatestView ? null : (latestView ?? this.latestView),
      pageError: clearPageError ? null : (pageError ?? this.pageError),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HomeState &&
        other.isLoading == isLoading &&
        other.workspaceId == workspaceId &&
        other.latestView == latestView &&
        other.pageError == pageError;
  }

  @override
  int get hashCode {
    return Object.hash(
      isLoading,
      workspaceId,
      latestView,
      pageError,
    );
  }

  @override
  String toString() {
    return 'HomeState(isLoading: $isLoading, workspaceId: $workspaceId, latestView: $latestView, pageError: $pageError)';
  }
}
