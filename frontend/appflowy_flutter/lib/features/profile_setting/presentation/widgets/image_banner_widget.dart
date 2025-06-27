import 'package:appflowy/features/profile_setting/data/banner.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class NetworkImageBannerWidget extends StatelessWidget {
  const NetworkImageBannerWidget({
    super.key,
    required this.banner,
    this.selected = false,
  });
  final NetworkImageBanner banner;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context), spacing = theme.spacing;
    const width = 160.5, height = 52.0;
    return SizedBox(
      height: height,
      width: width,
      child: Stack(
        children: [
          Container(
            height: height,
            width: width,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: CachedNetworkImageProvider(banner.url),
                fit: BoxFit.cover,
              ),
              borderRadius: BorderRadius.circular(spacing.m),
            ),
          ),
          if (selected)
            Container(
              height: height,
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.borderColorScheme.themeThick,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(spacing.m),
              ),
              child: Container(
                height: height - 4,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(spacing.s),
                ),
                child: SizedBox(height: height, width: width),
              ),
            ),
        ],
      ),
    );
  }
}

class AssetImageBannerWidget extends StatelessWidget {
  const AssetImageBannerWidget({
    super.key,
    required this.banner,
    this.selected = false,
  });
  final AssetImageBanner banner;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context), spacing = theme.spacing;
    const width = 160.5, height = 52.0;
    return SizedBox(
      height: height,
      width: width,
      child: Stack(
        children: [
          Container(
            height: height,
            width: width,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(banner.path),
                fit: BoxFit.cover,
              ),
              borderRadius: BorderRadius.circular(spacing.m),
            ),
          ),
          if (selected)
            Container(
              height: height,
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.borderColorScheme.themeThick,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(spacing.m),
              ),
              child: Container(
                height: height - 4,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(spacing.s),
                ),
                child: SizedBox(height: height, width: width),
              ),
            ),
        ],
      ),
    );
  }
}

class ColorBannerWidget extends StatelessWidget {
  const ColorBannerWidget({
    super.key,
    required this.banner,
    this.selected = false,
  });
  final ColorBanner banner;
  final bool selected;

  Color get color => banner.color;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context), spacing = theme.spacing;
    final unselectedWidget = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(spacing.m),
      ),
    );
    final selectedWidget = DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.borderColorScheme.themeThick, width: 2),
        borderRadius: BorderRadius.circular(spacing.m),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(spacing.xs),
          ),
        ),
      ),
    );
    return SizedBox(
      height: 52,
      child: selected ? selectedWidget : unselectedWidget,
    );
  }
}

extension BannerWidgetExtension on BannerData {
  Widget toWidget({
    required BuildContext context,
    required bool selected,
  }) {
    final banner = this;
    if (banner is ColorBanner) {
      return ColorBannerWidget(banner: banner, selected: selected);
    } else if (banner is AssetImageBanner) {
      return AssetImageBannerWidget(banner: banner, selected: selected);
    } else if (banner is NetworkImageBanner) {
      return NetworkImageBannerWidget(banner: banner, selected: selected);
    }
    throw Exception('Unknown BannerData type');
  }
}
