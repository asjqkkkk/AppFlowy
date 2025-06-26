import 'package:appflowy/features/profile_setting/data/banner.dart';
import 'package:appflowy/features/profile_setting/data/profile.dart';

class ProfileSettingState {
  ProfileSettingState({
    required this.profile,
    required this.status,
    this.selectedBanner,
  });

  ProfileSettingState.empty()
      : profile = Profile.empty(),
        status = ProfileSettingStatus.loading,
        selectedBanner = null;

  final Profile profile;
  final ProfileSettingStatus status;
  final BannerData? selectedBanner;

  ProfileSettingState copyWith({
    Profile? profile,
    ProfileSettingStatus? status,
    BannerData? selectedBanner,
  }) {
    return ProfileSettingState(
      profile: profile ?? this.profile,
      status: status ?? this.status,
      selectedBanner: selectedBanner ?? this.selectedBanner,
    );
  }
}

enum ProfileSettingStatus { idle, loading, failed }
