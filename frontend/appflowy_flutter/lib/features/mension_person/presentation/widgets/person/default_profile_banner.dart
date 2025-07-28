import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flutter/material.dart';
import 'package:universal_platform/universal_platform.dart';

class DefaultAssetProfileBanner extends StatelessWidget {
  const DefaultAssetProfileBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return SizedBox(
      width: double.infinity,
      height: UniversalPlatform.isMobile ? 92 : 80,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(theme.spacing.m),
        child: Image.asset(
          'assets/images/profile_banner/banner_purple.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
