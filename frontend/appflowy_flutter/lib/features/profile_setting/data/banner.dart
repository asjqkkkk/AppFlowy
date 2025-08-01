import 'dart:ui';

import 'package:appflowy_backend/log.dart';
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

  String get toUrl;

  static BannerData fromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return defaultBanners.first;
    try {
      if (uri.scheme == 'image') {
        if (uri.host == 'color-image') {
          final color = Color(int.parse(uri.queryParameters['color'] ?? ''));
          return ColorBanner(color: color);
        } else if (uri.host == 'asset-image') {
          final path = uri.queryParameters['path'] ?? '';
          return AssetImageBanner(path: path);
        } else if (uri.host == 'network-image') {
          final imageUrl = uri.queryParameters['url'] ?? '';
          return NetworkImageBanner(url: imageUrl);
        }
      }
    } catch (e) {
      Log.error('Failed to parse banner URL: $url', e);
    }
    return defaultBanners.first;
  }
}

class EmptyBanner extends BannerData {
  const EmptyBanner();

  static final EmptyBanner instance = EmptyBanner();

  @override
  List<Object?> get props => [];

  @override
  String get toUrl => '';
}

class ColorBanner extends BannerData {
  const ColorBanner({required this.color});

  final Color color;

  @override
  List<Object?> get props => [color];

  @override
  String get toUrl => 'image://color-image?color=${color.toString()}';
}

class AssetImageBanner extends BannerData {
  const AssetImageBanner({required this.path});

  final String path;

  @override
  List<Object?> get props => [path];

  @override
  String get toUrl => 'image://asset-image?path=$path';
}

class NetworkImageBanner extends BannerData {
  const NetworkImageBanner({required this.url});

  final String url;

  @override
  List<Object?> get props => [url];

  @override
  String get toUrl => url;
}
