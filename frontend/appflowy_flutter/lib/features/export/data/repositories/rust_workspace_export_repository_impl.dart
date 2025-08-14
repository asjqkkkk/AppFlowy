import 'package:appflowy/features/export/data/repositories/workspace_export_repository.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:appflowy_result/appflowy_result.dart';

class RustWorkspaceExportRepositoryImpl implements WorkspaceExportRepository {
  @override
  Future<FlowyResult<void, FlowyError>> exportWorkspace({
    required String workspaceId,
    required String exportPath,
    required String exportName,
    bool? includeFileAttachments,
  }) async {
    final request = ExportWorkspaceRequestPB()
      ..workspaceId = workspaceId
      ..outputPath = exportPath;
    if (includeFileAttachments != null) {
      request.includeFileAttachments = includeFileAttachments;
    }

    final result = await FolderEventExportWorkspace(request).send();
    return result.fold(
      (response) {
        Log.info('Successfully exported workspace: $workspaceId');
        return FlowyResult.success(null);
      },
      (error) {
        Log.error('Failed to export workspace: $error');
        return FlowyResult.failure(error);
      },
    );
  }
}
