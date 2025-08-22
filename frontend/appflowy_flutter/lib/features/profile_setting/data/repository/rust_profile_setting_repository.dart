import 'package:appflowy/features/profile_setting/data/banner.dart';
import 'package:appflowy/features/profile_setting/data/profile.dart';
import 'package:appflowy/features/share_tab/data/models/share_role.dart';
import 'package:appflowy/user/application/user_service.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';

import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/user_profile.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/workspace.pbenum.dart';
import 'package:appflowy_result/appflowy_result.dart';

import 'profile_setting_repository.dart';

class RustProfileSettingRepository implements ProfileSettingRepository {
  RustProfileSettingRepository({required this.userProfile});

  final UserProfilePB userProfile;

  bool get isServer => userProfile.workspaceType == WorkspaceTypePB.ServerW;
  @override
  Future<FlowyResult<Profile, FlowyError>> getProfile(String userId) async {
    if (!isServer) {
      return FlowyResult.success(
        Profile(
          id: '${userProfile.id}',
          email: userProfile.email,
          name: userProfile.name,
          avatarUrl: userProfile.iconUrl,
          aboutMe: '',
          role: ShareRole.member,
          banner: EmptyBanner.instance,
        ),
      );
    }
    final result =
        await ViewBackendService.getUserWorkspaceProfile();
    return result.fold((p) {
      final customCoverUrl = p.customCoverImageUrl;
      return FlowyResult.success(
        Profile(
          id: p.uuid,
          email: p.email,
          name: p.name,
          avatarUrl: p.avatarUrl,
          aboutMe: p.description,
          role: Profile.fromProtoToShareRole(p.role),
          banner: BannerData.fromUrl(p.coverImageUrl),
          customBanner: customCoverUrl.isEmpty
              ? null
              : NetworkImageBanner(url: customCoverUrl),
        ),
      );
    }, (e) {
      return FlowyResult.failure(e);
    });
  }

  @override
  Future<FlowyResult<void, FlowyError>> updateProfile(Profile profile) async {
    if (!isServer) {
      final result =
          await UserBackendService(userId: userProfile.id).updateUserProfile(
        name: profile.name,
        iconUrl: profile.avatarUrl,
      );
      return result.fold(
        (l) => FlowyResult.success(null),
        (r) => FlowyResult.success(null),
      );
    }
    final request = WorkspaceMemberProfilePB()
      ..name = profile.name
      ..description = profile.aboutMe
      ..avatarUrl = profile.avatarUrl
      ..coverImageUrl = profile.banner.toUrl;
    final customUrl = profile.customBanner?.toUrl;
    if (customUrl != null) {
      request.customCoverImageUrl = customUrl;
    }
    return ViewBackendService.updateWorkspaceMemberProfile(request);
  }
}
