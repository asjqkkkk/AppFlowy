import 'package:appflowy/features/profile_setting/data/banner.dart';
import 'package:appflowy/features/profile_setting/logic/profile_setting_bloc.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'role_badge.dart';

class ProfilePreviewWidget extends StatelessWidget {
  const ProfilePreviewWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context),
        spacing = theme.spacing,
        profile = context.read<ProfileSettingBloc>().state.profile;

    final hasDescription = profile.aboutMe.isNotEmpty;

    return Stack(
      children: [
        buildBanner(context),
        Padding(
          padding:
              EdgeInsets.fromLTRB(spacing.xxl, 148, spacing.xxl, spacing.xxl),
          child: SizedBox(
            width: 240,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                buildName(context),
                buildEmail(context),
                if (hasDescription) ...[
                  VSpace(spacing.m),
                  buildDescription(context),
                ],
                VSpace(spacing.xxl),
                buildRoleBadgeAndActions(context),
              ],
            ),
          ),
        ),
        Positioned(
          top: 38,
          left: 20,
          child: buildAvatar(context),
        ),
      ],
    );
  }

  Widget buildBanner(BuildContext context) {
    final theme = AppFlowyTheme.of(context),
        spacingM = theme.spacing.m,
        profile = context.read<ProfileSettingBloc>().state.profile;
    return Container(
      width: 264,
      height: 80,
      margin: EdgeInsets.fromLTRB(spacingM, spacingM, spacingM, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(theme.spacing.m),
        child: _Banner(banner: profile.banner),
      ),
    );
  }

  Widget buildAvatar(BuildContext context) {
    final theme = AppFlowyTheme.of(context),
        profile = context.read<ProfileSettingBloc>().state.profile;
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(46),
        color: theme.surfaceColorScheme.layer01,
      ),
      child: Center(
        child: Transform.scale(
          scale: 90 / AFAvatarSize.xxl.size,
          child: AFAvatar(
            url: profile.avatarUrl,
            radius: 41,
            size: AFAvatarSize.xxl,
            name: profile.name,
          ),
        ),
      ),
    );
  }

  Widget buildName(BuildContext context) {
    final theme = AppFlowyTheme.of(context),
        profile = context.read<ProfileSettingBloc>().state.profile;
    return Text(
      profile.name,
      style:
          theme.textStyle.title.prominent(color: theme.textColorScheme.primary),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget buildEmail(BuildContext context) {
    final theme = AppFlowyTheme.of(context),
        profile = context.read<ProfileSettingBloc>().state.profile;
    return Text(
      profile.email,
      style:
          theme.textStyle.body.standard(color: theme.textColorScheme.secondary),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget buildDescription(BuildContext context) {
    final theme = AppFlowyTheme.of(context),
        profile = context.read<ProfileSettingBloc>().state.profile;
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.fillColorScheme.contentVisible,
          borderRadius: BorderRadius.circular(theme.spacing.m),
        ),
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.l),
          child: Text(
            profile.aboutMe,
            style: theme.textStyle.caption
                .standard(color: theme.textColorScheme.primary),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget buildRoleBadgeAndActions(BuildContext context) {
    final theme = AppFlowyTheme.of(context),
        profile = context.read<ProfileSettingBloc>().state.profile;
    return SizedBox(
      width: 240,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShareRoleBadge(role: profile.role),
          Spacer(),
          IgnorePointer(
            child: AFOutlinedButton.normal(
              padding: EdgeInsets.all(theme.spacing.s),
              builder: (context, hovering, disabled) {
                return FlowySvg(
                  FlowySvgs.mention_send_notification_m,
                  size: Size.square(20),
                  color: theme.iconColorScheme.primary,
                );
              },
              onTap: () {},
            ),
          ),
          HSpace(theme.spacing.m),
          IgnorePointer(
            child: AFOutlinedButton.normal(
              padding: EdgeInsets.all(theme.spacing.s),
              builder: (context, hovering, disabled) {
                return FlowySvg(
                  FlowySvgs.mention_more_results_m,
                  size: Size.square(20),
                  color: theme.iconColorScheme.primary,
                );
              },
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.banner});

  final BannerData banner;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return SizedBox(
      width: 264,
      height: 80,
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
