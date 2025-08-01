import 'package:appflowy/features/profile_setting/data/profile.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';

abstract class ProfileSettingRepository {
  Future<FlowyResult<Profile, FlowyError>> getProfile(String userId);

  Future<FlowyResult<void, FlowyError>> updateProfile(Profile profile);
}
