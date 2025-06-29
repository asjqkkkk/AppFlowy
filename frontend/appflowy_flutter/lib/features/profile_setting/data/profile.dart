import 'package:appflowy/features/share_tab/data/models/share_role.dart';
import 'banner.dart';

class Profile {
  Profile.empty()
      : id = '',
        email = '',
        name = '',
        avatarUrl = '',
        aboutMe = '',
        role = ShareRole.member,
        banner = EmptyBanner.instance,
        customBanner = null;

  Profile({
    required this.id,
    required this.email,
    required this.name,
    required this.avatarUrl,
    required this.aboutMe,
    required this.banner,
    required this.role,
    this.customBanner,
  });

  final String id;
  final String email;
  final String name;
  final String avatarUrl;
  final String aboutMe;
  final ShareRole role;
  final BannerData banner;
  final NetworkImageBanner? customBanner;

  Profile copyWith({
    String? id,
    String? email,
    String? name,
    String? avatarUrl,
    String? aboutMe,
    ShareRole? role,
    BannerData? banner,
    NetworkImageBanner? customBanner,
  }) {
    return Profile(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      aboutMe: aboutMe ?? this.aboutMe,
      role: role ?? this.role,
      banner: banner ?? this.banner,
      customBanner: customBanner ?? this.customBanner,
    );
  }
}
