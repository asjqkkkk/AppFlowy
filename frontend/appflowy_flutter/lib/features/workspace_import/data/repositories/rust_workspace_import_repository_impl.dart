import 'package:appflowy/features/workspace_import/data/repositories/workspace_import_repository.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:appflowy_result/appflowy_result.dart';

class RustWorkspaceImportRepositoryImpl implements WorkspaceImportRepository {
  @override
  Future<FlowyResult<void, FlowyError>> importWorkspace({
    required String archivePath,
    String? workspaceName,
  }) async {
    final value = ImportZipPB()
      ..filePath = archivePath
      ..taskType = ImportTaskTypePB.AppFlowyWorkspace;
    final stopWatch = Stopwatch()..start();
    final result = await FolderEventImportZipFile(value).send();
    Log.info('Import workspace took ${stopWatch.elapsed}');
    return result.fold(
      (response) {
        return FlowyResult.success(null);
      },
      (error) {
        Log.error('Failed to import workspace: $error');
        return FlowyResult.failure(error);
      },
    );
  }
}
