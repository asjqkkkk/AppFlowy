import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';

abstract class WorkspaceImportRepository {
  Future<FlowyResult<void, FlowyError>> importWorkspace({
    required String archivePath,
    String? workspaceName,
  });
}
