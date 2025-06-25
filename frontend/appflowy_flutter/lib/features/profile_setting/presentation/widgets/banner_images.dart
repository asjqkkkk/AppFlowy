import 'package:appflowy/features/profile_setting/data/banner.dart';
import 'package:appflowy/features/profile_setting/logic/profile_setting_bloc.dart';
import 'package:appflowy/features/profile_setting/logic/profile_setting_event.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

List<BannerData> _defaultBanners(BuildContext context) {
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
    final theme = AppFlowyTheme.of(context),
        spacing = theme.spacing,
        bloc = context.read<ProfileSettingBloc>(),
        state = bloc.state;
    final banners = _defaultBanners(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          LocaleKeys.settings_profilePage_bannerImage.tr(),
          style: theme.textStyle.body
              .enhanced(color: theme.textColorScheme.primary),
        ),
        VSpace(spacing.l),
        Text(
          LocaleKeys.settings_profilePage_customImage.tr(),
          style: theme.textStyle.caption
              .prominent(color: theme.textColorScheme.tertiary),
        ),
        VSpace(spacing.xs),
        _UploadButton(onTap: () {}),
        VSpace(spacing.xxl),
        Text(
          LocaleKeys.settings_profilePage_wallpapers.tr(),
          style: theme.textStyle.caption
              .prominent(color: theme.textColorScheme.tertiary),
        ),
        VSpace(spacing.xs),
        GridView.count(
          crossAxisCount: 4,
          mainAxisSpacing: spacing.s,
          crossAxisSpacing: spacing.s,
          childAspectRatio: 160 / 52,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: banners.map((banner) {
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  bloc.add(ProfileSettingSelectBannerEvent(banner));
                },
                child: banner.toWidget(
                  context: context,
                  selected: banner == state.selectedBanner,
                ),
              ),
            );
          }).toList(),
        ),
      ],
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
      width: 160,
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
      height: 52,
      width: 160,
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 159,
          height: 52,
          decoration: BoxDecoration(
            border: Border.all(color: theme.borderColorScheme.primary),
            borderRadius: BorderRadius.circular(theme.spacing.m),
          ),
          child: Center(
            child: FlowySvg(
              FlowySvgs.profile_add_icon_m,
              size: Size.square(20),
              color: theme.iconColorScheme.primary,
            ),
          ),
        ),
      ),
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
