import 'dart:ui';

abstract class BannerData {}

class ColorBanner implements BannerData {
  ColorBanner({required this.color});

  final Color color;
}

class AssetImageBanner implements BannerData {
  AssetImageBanner({required this.path});

  final String path;
}
