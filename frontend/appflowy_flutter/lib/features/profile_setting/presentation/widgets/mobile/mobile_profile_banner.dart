import 'package:appflowy/features/profile_setting/data/banner.dart';
import 'package:appflowy/features/profile_setting/logic/profile_setting_bloc.dart';
import 'package:appflowy/features/workspace/logic/workspace_bloc.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/shared/appflowy_network_image.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
            child: buildBanner(context),
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

  Widget buildBanner(BuildContext context) {
    final banner = this.banner;
    if (banner is ColorBanner) {
      return DecoratedBox(decoration: BoxDecoration(color: banner.color));
    } else if (banner is AssetImageBanner) {
      return Image.asset(banner.path, fit: BoxFit.cover);
    } else if (banner is NetworkImageBanner) {
      return FlowyNetworkImage(
        url: banner.url,
        userProfilePB: context.read<ProfileSettingBloc>().userProfile,
      );
    }
    return const SizedBox.shrink();
  }

  Widget buildEditButton(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return GestureDetector(
      onTap: () => showMobileContactDetailMenu(
        context: context,
        userProfile: context.read<UserWorkspaceBloc>().userProfile,
      ),
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
