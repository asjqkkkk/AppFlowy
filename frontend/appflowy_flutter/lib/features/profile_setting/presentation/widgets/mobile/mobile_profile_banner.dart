import 'package:appflowy/features/profile_setting/data/banner.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'mobile_edit_banner_bottom_sheet.dart';

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
    final theme = AppFlowyTheme.of(context), spacing = theme.spacing;
    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(theme.spacing.m),
            child: buildBanner(),
          ),
          Positioned(
            top: spacing.m,
            right: spacing.m,
            child: buildEditButton(context),
          ),
        ],
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

  Widget buildEditButton(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return GestureDetector(
      onTap: () => showMobileContactDetailMenu(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.all(theme.spacing.xs),
        decoration: BoxDecoration(
          color: theme.surfaceColorScheme.layer01,
          borderRadius: BorderRadius.circular(theme.spacing.s),
        ),
        child: FlowySvg(
          FlowySvgs.banner_edit_icon_s,
          size: Size.square(16),
          color: theme.iconColorScheme.secondary,
        ),
      ),
    );
  }
}
