import 'package:appflowy/features/profile_setting/data/banner.dart';
import 'package:appflowy/shared/appflowy_network_image.dart';
import 'package:appflowy_backend/protobuf/flowy-user/user_profile.pb.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flutter/material.dart';
import 'package:universal_platform/universal_platform.dart';

class ProfileBanner extends StatelessWidget {
  const ProfileBanner({
    super.key,
    required this.url,
    required this.userProfile,
  });
  final String url;
  final UserProfilePB userProfile;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return SizedBox(
      width: double.infinity,
      height: UniversalPlatform.isMobile ? 92 : 80,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(theme.spacing.m),
        child: buildBanner(),
      ),
    );
  }

  Widget buildBanner() {
    final banner = BannerData.fromUrl(url);
    if (banner is ColorBanner) {
      return DecoratedBox(decoration: BoxDecoration(color: banner.color));
    } else if (banner is AssetImageBanner) {
      return Image.asset(banner.path, fit: BoxFit.cover);
    } else if (banner is NetworkImageBanner) {
      return FlowyNetworkImage(url: banner.url, userProfilePB: userProfile);
    }
    return const SizedBox.shrink();
  }
}
