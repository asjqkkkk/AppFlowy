import 'package:appflowy/features/profile_setting/data/banner.dart';
import 'package:appflowy/features/profile_setting/data/profile.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';

import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';

import 'profile_setting_repository.dart';

class RustProfileSettingRepository implements ProfileSettingRepository {
  @override
  Future<FlowyResult<Profile, FlowyError>> getProfile(String userId) async {
    final result =
        await ViewBackendService.getWorkspaceMentionablePerson(userId);
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
    final request = WorkspaceMemberProfilePB()
      ..name = profile.name
      ..description = profile.aboutMe
      ..avatarUrl = profile.avatarUrl
      ..coverImageUrl = profile.banner.toUrl;
    return ViewBackendService.updateWorkspaceMemberProfile(request);
  }
}
