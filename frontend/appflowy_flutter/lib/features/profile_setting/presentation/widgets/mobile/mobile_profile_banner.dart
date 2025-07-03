import 'package:appflowy/features/profile_setting/data/banner.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class MobileProfileBanner extends StatelessWidget {
  const MobileProfileBanner({
    super.key,
    required this.size,
    required this.banner,
  });

  final Size size;
  final BannerData banner;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return SizedBox(
      width: size.width,
      height: size.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(theme.spacing.m),
        child: buildBanner(),
      ),
    );
  }

  Widget buildBanner() {
    final banner = this.banner;
    if (banner is ColorBanner) {
      return DecoratedBox(decoration: BoxDecoration(color: banner.color));
    } else if (banner is AssetImageBanner) {
      return Image.asset(banner.path, fit: BoxFit.cover);
    } else if (banner is NetworkImageBanner) {
      return CachedNetworkImage(imageUrl: banner.url, fit: BoxFit.cover);
    }
    return const SizedBox.shrink();
  }
}
