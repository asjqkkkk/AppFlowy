import 'package:appflowy/features/profile_setting/data/banner.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';

List<BannerData> defaultBanners(BuildContext context) {
  final theme = AppFlowyTheme.of(context), badgeColor = theme.badgeColorScheme;
  return [
    ColorBanner(color: badgeColor.color14Light2),
    ColorBanner(color: badgeColor.color8Light2),
    ColorBanner(color: badgeColor.color5Light2),
    ColorBanner(color: badgeColor.color1Light2),
    AssetImageBanner(path: 'assets/images/profile_banner/banner_purple.png'),
    AssetImageBanner(path: 'assets/images/profile_banner/banner_blue.png'),
    AssetImageBanner(path: 'assets/images/profile_banner/banner_yellow.png'),
    AssetImageBanner(path: 'assets/images/profile_banner/banner_pink.png'),
  ];
}

class BannerImages extends StatelessWidget {
  const BannerImages({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context), spacing = theme.spacing;
    final banners = defaultBanners(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        buildTitle(context),
        VSpace(spacing.l),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: List.generate(banners.length ~/ 4, (index) {
              return Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : spacing.s),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(4, (i) {
                    final currentIndex = i + (4 * index);
                    final banner = banners[currentIndex];
                    return Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : spacing.s),
                      child: banner.toWidget(
                        context: context,
                        selected: currentIndex == 4,
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
        ),
        VSpace(spacing.l),
        _UploadButton(onTap: () {}),
      ],
    );
  }

  Widget buildTitle(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return Text(
      LocaleKeys.settings_profilePage_bannerImage_title.tr(),
      style:
          theme.textStyle.body.enhanced(color: theme.textColorScheme.primary),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
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
      height: 40,
      width: 82.5,
      child: selected ? selectedWidget : unselectedWidget,
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
    final unselectedWidget = DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(banner.path),
          fit: BoxFit.cover,
        ),
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
            image: DecorationImage(
              image: AssetImage(banner.path),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.circular(spacing.xs),
          ),
        ),
      ),
    );
    return SizedBox(
      height: 40,
      width: 82.5,
      child: selected ? selectedWidget : unselectedWidget,
    );
  }
}

class _UploadButton extends StatelessWidget {
  const _UploadButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return AFOutlinedTextButton.normal(
      text: LocaleKeys.settings_profilePage_bannerImage_upload.tr(),
      textStyle: theme.textStyle.body.enhanced(
        color: theme.textColorScheme.primary,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.l,
        vertical: theme.spacing.s,
      ),
      onTap: onTap,
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
