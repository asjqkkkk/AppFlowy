import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/features/profile_setting/presentation/widgets/banner_images.dart';
import 'package:appflowy_backend/protobuf/flowy-user/user_profile.pb.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';

class SettingsProfileView extends StatelessWidget {
  const SettingsProfileView({
    super.key,
    required this.userProfile,
    this.workspace,
  });

  final UserProfilePB userProfile;
  final UserWorkspacePB? workspace;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return LayoutBuilder(
      builder: (context, constrains) {
        final isNarrowWindow = constrains.maxWidth < 380;
        return Padding(
          padding: EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                buildTitle(context),
                VSpace(theme.spacing.xl),
                Row(
                  children: [
                    Expanded(child: buildInfoLists(context)),
                    HSpace(24),
                    if (!isNarrowWindow) buildPreview(context),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildTitle(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return Text(
      LocaleKeys.settings_profilePage_title.tr(),
      style: theme.textStyle.heading2
          .enhanced(color: theme.textColorScheme.primary),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget buildInfoLists(BuildContext context) {
    final theme = AppFlowyTheme.of(context), spacing = theme.spacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...displayName(context),
        VSpace(spacing.xxl),
        ...aboutMe(context),
        VSpace(spacing.xxl),
        ...avatar(context),
        VSpace(spacing.xxl),
        BannerImages(),
      ],
    );
  }

  List<Widget> displayName(BuildContext context) {
    final theme = AppFlowyTheme.of(context), spacing = theme.spacing;
    return [
      Text(
        LocaleKeys.settings_profilePage_displayName_title.tr(),
        style:
            theme.textStyle.body.enhanced(color: theme.textColorScheme.primary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      VSpace(spacing.xs),
      Text(
        userProfile.name,
        style: theme.textStyle.caption
            .standard(color: theme.textColorScheme.secondary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      VSpace(spacing.l),
      _EditButton(
        onTap: () {},
      ),
    ];
  }

  List<Widget> aboutMe(BuildContext context) {
    final theme = AppFlowyTheme.of(context), spacing = theme.spacing;
    return [
      Text(
        LocaleKeys.settings_profilePage_aboutMe_title.tr(),
        style:
            theme.textStyle.body.enhanced(color: theme.textColorScheme.primary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      VSpace(spacing.xs),
      Text(
        userProfile.name,
        style: theme.textStyle.caption
            .standard(color: theme.textColorScheme.secondary),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      VSpace(spacing.l),
      _EditButton(
        onTap: () {},
      ),
    ];
  }

  List<Widget> avatar(BuildContext context) {
    final theme = AppFlowyTheme.of(context), spacing = theme.spacing;
    return [
      Text(
        LocaleKeys.settings_profilePage_aboutMe_title.tr(),
        style:
            theme.textStyle.body.enhanced(color: theme.textColorScheme.primary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      VSpace(spacing.l),
      _EditButton(
        onTap: () {},
      ),
    ];
  }

  Widget buildPreview(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [],
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return AFOutlinedTextButton.normal(
      text: LocaleKeys.settings_profilePage_edit.tr(),
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
