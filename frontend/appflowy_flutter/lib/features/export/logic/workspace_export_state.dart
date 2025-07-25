import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';

class WorkspaceExportState {
  factory WorkspaceExportState.initial(String workspaceId) =>
      WorkspaceExportState(
        workspaceId: workspaceId,
      );
  const WorkspaceExportState({
    required this.workspaceId,
    this.isLoading = false,
    this.isExporting = false,
    this.exportResult,
    this.exportPath,
    this.exportName,
  });

  final String workspaceId;
  final bool isLoading;
  final bool isExporting;
  final FlowyResult<void, FlowyError>? exportResult;
  final String? exportPath;
  final String? exportName;

  WorkspaceExportState copyWith({
    String? workspaceId,
    bool? isLoading,
    bool? isExporting,
    FlowyResult<void, FlowyError>? exportResult,
    String? exportPath,
    String? exportName,
  }) {
    return WorkspaceExportState(
      workspaceId: workspaceId ?? this.workspaceId,
      isLoading: isLoading ?? this.isLoading,
      isExporting: isExporting ?? this.isExporting,
      exportResult: exportResult ?? this.exportResult,
      exportPath: exportPath ?? this.exportPath,
      exportName: exportName ?? this.exportName,
    );
  }

  @override
  String toString() {
    return 'WorkspaceExportState('
        'workspaceId: $workspaceId, '
        'isLoading: $isLoading, '
        'isExporting: $isExporting, '
        'exportPath: $exportPath, '
        'exportName: $exportName'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is WorkspaceExportState &&
        other.workspaceId == workspaceId &&
        other.isLoading == isLoading &&
        other.isExporting == isExporting &&
        other.exportResult == exportResult &&
        other.exportPath == exportPath &&
        other.exportName == exportName;
  }

  @override
  int get hashCode {
    return workspaceId.hashCode ^
        isLoading.hashCode ^
        isExporting.hashCode ^
        exportResult.hashCode ^
        exportPath.hashCode ^
        exportName.hashCode;
  }
}
