import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';

class BannerImages extends StatelessWidget {
  const BannerImages({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context),
        badgeColor = theme.badgeColorScheme,
        spacing = theme.spacing;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          buildTitle(context),
          VSpace(spacing.l),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ColorBanner(color: badgeColor.color14Light2),
              HSpace(spacing.s),
              ColorBanner(color: badgeColor.color8Light2),
              HSpace(spacing.s),
              ColorBanner(color: badgeColor.color5Light2),
              HSpace(spacing.s),
              ColorBanner(color: badgeColor.color1Light2),
            ],
          ),
          VSpace(spacing.l),
          _UploadButton(onTap: () {})
        ],
      ),
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

class ColorBanner extends StatelessWidget {
  const ColorBanner({super.key, required this.color, this.selected = false});
  final Color color;
  final bool selected;

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
