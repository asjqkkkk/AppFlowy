import 'package:appflowy/features/profile_setting/data/banner.dart';

sealed class ProfileSettingEvent {
  const ProfileSettingEvent();

  const factory ProfileSettingEvent.initial() = ProfileSettingInitialEvent;
  const factory ProfileSettingEvent.updateName(String name) =
      ProfileSettingUpdateNameEvent;
  const factory ProfileSettingEvent.updateAboutMe(String aboutMe) =
      ProfileSettingUpdateAboutMeEvent;
  const factory ProfileSettingEvent.updateAvatar(String avatarUrl) =
      ProfileSettingUpdateAvatarEvent;
  const factory ProfileSettingEvent.uploadBanner(NetworkImageBanner? banner) =
      ProfileSettingUploadBannerEvent;
  const factory ProfileSettingEvent.selectBanner(BannerData banner) =
      ProfileSettingSelectBannerEvent;
}

class ProfileSettingInitialEvent implements ProfileSettingEvent {
  const ProfileSettingInitialEvent();
}

class ProfileSettingUpdateNameEvent implements ProfileSettingEvent {
  const ProfileSettingUpdateNameEvent(this.name);

  final String name;
}

class ProfileSettingUpdateAboutMeEvent implements ProfileSettingEvent {
  const ProfileSettingUpdateAboutMeEvent(this.aboutMe);

  final String aboutMe;
}

class ProfileSettingUpdateAvatarEvent implements ProfileSettingEvent {
  const ProfileSettingUpdateAvatarEvent(this.avatarUrl);

  final String avatarUrl;
}

class ProfileSettingUploadBannerEvent implements ProfileSettingEvent {
  const ProfileSettingUploadBannerEvent(this.banner);

  final NetworkImageBanner? banner;
}

class ProfileSettingSelectBannerEvent implements ProfileSettingEvent {
  const ProfileSettingSelectBannerEvent(this.banner);

  final BannerData banner;
}
