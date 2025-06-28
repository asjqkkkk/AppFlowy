import 'package:appflowy/features/profile_setting/data/banner.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class NetworkImageBannerWidget extends StatelessWidget {
  const NetworkImageBannerWidget({
    super.key,
    required this.banner,
    this.selected = false,
    this.hovering = false,
  });
  final NetworkImageBanner banner;
  final bool selected;
  final bool hovering;

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
          context._buildBorder(hovering: hovering, selected: selected),
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
    return _HoverBuilderWidget(
      builder: (context, hovering) {
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
              context._buildBorder(hovering: hovering, selected: selected),
            ],
          ),
        );
      },
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
    const width = 160.5, height = 52.0;
    return _HoverBuilderWidget(
      builder: (context, hovering) {
        return SizedBox(
          height: height,
          width: width,
          child: Stack(
            children: [
              Container(
                height: height,
                width: width,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(spacing.m),
                ),
              ),
              context._buildBorder(hovering: hovering, selected: selected),
            ],
          ),
        );
      },
    );
  }
}

typedef _HoverBuilder = Widget Function(BuildContext context, bool hovering);

class _HoverBuilderWidget extends StatefulWidget {
  const _HoverBuilderWidget({
    required this.builder,
  });

  final _HoverBuilder builder;

  @override
  State<_HoverBuilderWidget> createState() => __HoverBuilderWidgetState();
}

class __HoverBuilderWidgetState extends State<_HoverBuilderWidget> {
  _HoverBuilder get builder => widget.builder;

  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (e) => setState(() {
        hovering = true;
      }),
      onExit: (e) => setState(() {
        hovering = false;
      }),
      child: builder.call(context, hovering),
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
    }
    throw Exception('Unknown BannerData type');
  }
}

extension on BuildContext {
  Widget _buildBorder({
    required bool selected,
    required bool hovering,
  }) {
    if (!selected && !hovering) return SizedBox.shrink();
    final theme = AppFlowyTheme.of(this), spacing = theme.spacing;
    const width = 160.5, height = 52.0;
    Color borderColor = theme.borderColorScheme.themeThick;
    if (!selected && hovering) {
      borderColor = theme.borderColorScheme.primaryHover;
    }
    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 2),
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
    );
  }
}
