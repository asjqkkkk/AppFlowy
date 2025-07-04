import 'dart:ui';

import 'package:equatable/equatable.dart';

final List<BannerData> defaultBanners = const [
  AssetImageBanner(path: 'assets/images/profile_banner/banner_purple.png'),
  AssetImageBanner(path: 'assets/images/profile_banner/banner_blue.png'),
  AssetImageBanner(path: 'assets/images/profile_banner/banner_yellow.png'),
  AssetImageBanner(path: 'assets/images/profile_banner/banner_pink.png'),
  ColorBanner(color: Color(0xffE6E6FA)),
  ColorBanner(color: Color(0xffE9F5D7)),
  ColorBanner(color: Color(0xffFCF5CF)),
  ColorBanner(color: Color(0xffFAE3E3)),
];

abstract class BannerData extends Equatable {
  const BannerData();
}

class EmptyBanner extends BannerData {
  const EmptyBanner();

  static final EmptyBanner instance = EmptyBanner();

  @override
  List<Object?> get props => [];
}

class ColorBanner extends BannerData {
  const ColorBanner({required this.color});

  final Color color;

  @override
  List<Object?> get props => [color];
}

class AssetImageBanner extends BannerData {
  const AssetImageBanner({required this.path});

  final String path;

  @override
  List<Object?> get props => [path];
}

class NetworkImageBanner extends BannerData {
  const NetworkImageBanner({required this.url});

  final String url;

  @override
  List<Object?> get props => [url];
}
