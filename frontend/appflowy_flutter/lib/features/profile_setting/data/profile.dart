import 'banner.dart';

class Profile {
  Profile.empty()
      : id = '',
        email = '',
        name = '',
        avatarUrl = '',
        about = '',
        banner = EmptyBanner.instance;

  Profile({
    required this.id,
    required this.email,
    required this.name,
    required this.avatarUrl,
    required this.about,
    required this.banner,
  });

  final String id;
  final String email;
  final String name;
  final String avatarUrl;
  final String about;
  final BannerData banner;

  Profile copyWith({
    String? id,
    String? email,
    String? name,
    String? avatarUrl,
    String? about,
    BannerData? banner,
  }) {
    return Profile(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      about: about ?? this.about,
      banner: banner ?? this.banner,
    );
  }
}
