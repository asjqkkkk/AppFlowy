import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';

abstract class WorkspaceExportRepository {
  Future<FlowyResult<void, FlowyError>> exportWorkspace({
    required String workspaceId,
    required String exportPath,
    required String exportName,
    bool? includeFileAttachments,
  });
}
