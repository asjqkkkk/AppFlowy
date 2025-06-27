import 'dart:ui';

import 'package:equatable/equatable.dart';

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
