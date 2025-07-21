import 'package:appflowy/features/profile_setting/data/profile.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';

import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';


import 'profile_setting_repository.dart';

class RustProfileSettingRepository implements ProfileSettingRepository {
  @override
  Future<FlowyResult<Profile, FlowyError>> getProfile(String userId) {
    // TODO: implement getProfile
    throw UnimplementedError();
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
