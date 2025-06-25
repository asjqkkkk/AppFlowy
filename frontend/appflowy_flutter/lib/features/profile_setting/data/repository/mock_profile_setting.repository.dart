import 'package:appflowy/features/profile_setting/data/banner.dart';
import 'package:appflowy/features/profile_setting/data/profile.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';

import 'profile_setting_repository.dart';

class MockProfileSettingRepository implements ProfileSettingRepository {
  @override
  Future<FlowyResult<Profile, FlowyError>> getProfile(String userId) async {
    return FlowyResult.success(_mockProfile);
  }

  @override
  Future<FlowyResult<String, FlowyError>> updateProfile(Profile profile) async {
    _mockProfile = profile;
    return FlowyResult.success('Profile updated successfully');
  }
}

Profile _mockProfile = Profile(
  id: 'mock_user_id',
  name: 'Mock User',
  email: 'appflowy@mock.io',
  avatarUrl:
      'https://m.media-amazon.com/images/S/pv-target-images/ae4816cade1a5b7f29787d0b89610132c72c7747041481c6619b9cc3302c0101.jpg',
  about: 'This is a mock user profile for testing purposes.',
  banner: EmptyBanner.instance,
);
