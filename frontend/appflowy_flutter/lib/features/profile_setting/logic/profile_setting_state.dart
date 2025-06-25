import 'package:appflowy/features/profile_setting/data/profile.dart';

class ProfileSettingState {
  ProfileSettingState({required this.profile, required this.status});

  ProfileSettingState.empty()
      : profile = Profile.empty(),
        status = ProfileSettingStatus.loading;

  final Profile profile;
  final ProfileSettingStatus status;

  ProfileSettingState copyWith({
    Profile? profile,
    ProfileSettingStatus? status,
  }) {
    return ProfileSettingState(
      profile: profile ?? this.profile,
      status: status ?? this.status,
    );
  }
}

enum ProfileSettingStatus { idle, loading, failed }
