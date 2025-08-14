import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';

sealed class WorkspaceExportEvent {
  const WorkspaceExportEvent();

  factory WorkspaceExportEvent.initial({
    required String workspaceId,
  }) =>
      WorkspaceExportInitialEvent(workspaceId: workspaceId);

  factory WorkspaceExportEvent.export({
    required String workspaceId,
    required String exportPath,
    required String exportName,
  }) =>
      WorkspaceExportStartEvent(
        workspaceId: workspaceId,
        exportPath: exportPath,
        exportName: exportName,
      );
}

/// Initializes the workspace export bloc.
class WorkspaceExportInitialEvent extends WorkspaceExportEvent {
  const WorkspaceExportInitialEvent({
    required this.workspaceId,
  });

  final String workspaceId;
}

/// Starts the workspace export process.
class WorkspaceExportStartEvent extends WorkspaceExportEvent {
  const WorkspaceExportStartEvent({
    required this.workspaceId,
    required this.exportPath,
    required this.exportName,
    this.includeFileAttachments = true,
  });

  final String workspaceId;
  final String exportPath;
  final String exportName;
  final bool includeFileAttachments;
}

/// Updates the export progress.
class WorkspaceExportUpdateProgressEvent extends WorkspaceExportEvent {
  const WorkspaceExportUpdateProgressEvent({
    required this.progress,
  });

  final ExportProgressResponsePB progress;
}
