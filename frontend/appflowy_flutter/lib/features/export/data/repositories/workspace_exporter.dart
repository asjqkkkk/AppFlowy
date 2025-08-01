import 'package:appflowy/features/export/logic/workspace_export_bloc.dart';
import 'package:appflowy/user/application/user_service.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';

enum WorkspaceExportType {
  appflowy,
  zip,
}

class WorkspaceExporter {
  const WorkspaceExporter();

  Future<FlowyResult<void, FlowyError>> exportWorkspace(
    WorkspaceExportType type, {
    required String exportPath,
    required String exportName,
  }) async {
    final workspaceResult = await UserBackendService.getCurrentWorkspace();

    return workspaceResult.fold(
      (workspace) async {
        final exportBloc = WorkspaceExportBloc(workspaceId: workspace.id);

        exportBloc.add(
          WorkspaceExportEvent.export(
            workspaceId: workspace.id,
            exportPath: exportPath,
            exportName: exportName,
          ),
        );

        final result = await exportBloc.exportRepository.exportWorkspace(
          workspaceId: workspace.id,
          exportPath: exportPath,
          exportName: exportName,
        );

        // don't use bloc here.
        await exportBloc.close();

        return result;
      },
      (error) => FlowyResult.failure(error),
    );
  }

  /// Checks if workspace export is available
  static bool isExportAvailable() {
    // You can add feature flags or other checks here
    return true;
  }
}
