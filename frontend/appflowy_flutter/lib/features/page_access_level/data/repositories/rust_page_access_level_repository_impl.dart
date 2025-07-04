import 'package:appflowy/features/page_access_level/data/repositories/page_access_level_repository.dart';
import 'package:appflowy/features/share_tab/data/models/models.dart';
import 'package:appflowy/features/util/extensions.dart';
import 'package:appflowy/user/application/user_service.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-error/code.pbenum.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart'
    hide AFRolePB;
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_result/appflowy_result.dart';

class RustPageAccessLevelRepositoryImpl implements PageAccessLevelRepository {
  @override
  Future<FlowyResult<ViewPB, FlowyError>> getView(String pageId) async {
    final result = await ViewBackendService.getView(pageId);
    return result.fold(
      (view) {
        return FlowyResult.success(view);
      },
      (error) {
        return FlowyResult.failure(error);
      },
    );
  }

  @override
  Future<FlowyResult<void, FlowyError>> lockView(String pageId) async {
    final result = await ViewBackendService.lockView(pageId);
    return result.fold(
      (_) {
        return FlowyResult.success(null);
      },
      (error) {
        Log.error('failed to lock view, error: $error');
        return FlowyResult.failure(error);
      },
    );
  }

  @override
  Future<FlowyResult<void, FlowyError>> unlockView(String pageId) async {
    final result = await ViewBackendService.unlockView(pageId);
    return result.fold(
      (_) {
        return FlowyResult.success(null);
      },
      (error) {
        Log.error('failed to unlock view, error: $error');
        return FlowyResult.failure(error);
      },
    );
  }

  @override
  Future<FlowyResult<ShareAccessLevel, FlowyError>> getAccessLevel(
    String pageId,
    String email,
  ) async {
    final request = GetAccessLevelPayloadPB(
      viewId: pageId,
      userEmail: email,
    );
    final result = await FolderEventGetAccessLevel(request).send();
    return result.fold(
      (success) {
        return FlowyResult.success(success.accessLevel.shareAccessLevel);
      },
      (failure) {
        return FlowyResult.failure(failure);
      },
    );
  }

  @override
  Future<FlowyResult<SharedSectionType, FlowyError>> getSectionType(
    String pageId,
  ) async {
    final request = ViewIdPB(value: pageId);
    final result = await FolderEventGetSharedViewSection(request).send();
    return result.fold(
      (success) {
        final sectionType = success.section.sharedSectionType;
        return FlowyResult.success(sectionType);
      },
      (failure) {
        return FlowyResult.failure(failure);
      },
    );
  }

  @override
  Future<FlowyResult<UserWorkspacePB, FlowyError>> getCurrentWorkspace() async {
    final result = await UserBackendService.getCurrentWorkspace();
    final currentWorkspaceId = result.fold(
      (s) => s.id,
      (_) => null,
    );

    if (currentWorkspaceId == null) {
      return FlowyResult.failure(
        FlowyError(
          code: ErrorCode.Internal,
          msg: 'Current workspace not found',
        ),
      );
    }

    final workspaceResult = await UserBackendService.getWorkspaceById(
      currentWorkspaceId,
    );
    return workspaceResult;
  }

  @override
  Future<FlowyResult<UserProfilePB, FlowyError>> getCurrentUserProfile() async {
    final result = await UserEventGetUserProfile().send();
    return result;
  }
}
