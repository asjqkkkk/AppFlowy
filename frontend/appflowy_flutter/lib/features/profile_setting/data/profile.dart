import 'banner.dart';

class Profile {
  Profile.empty()
      : id = '',
        email = '',
        name = '',
        avatarUrl = '',
        aboutMe = '',
        banner = EmptyBanner.instance,
        customBanner = null;

  Profile({
    required this.id,
    required this.email,
    required this.name,
    required this.avatarUrl,
    required this.aboutMe,
    required this.banner,
    this.customBanner,
  });

  final String id;
  final String email;
  final String name;
  final String avatarUrl;
  final String aboutMe;
  final BannerData banner;
  final NetworkImageBanner? customBanner;

  Profile copyWith({
    String? id,
    String? email,
    String? name,
    String? avatarUrl,
    String? aboutMe,
    BannerData? banner,
    NetworkImageBanner? customBanner,
  }) {
    return Profile(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      aboutMe: aboutMe ?? this.aboutMe,
      banner: banner ?? this.banner,
      customBanner: customBanner ?? this.customBanner,
    );
  }
}
