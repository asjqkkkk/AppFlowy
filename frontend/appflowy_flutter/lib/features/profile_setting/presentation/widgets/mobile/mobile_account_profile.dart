import 'package:appflowy/features/profile_setting/logic/profile_setting_bloc.dart';
import 'package:appflowy/features/profile_setting/presentation/widgets/profile_preview_widget.dart';
import 'package:appflowy_backend/protobuf/flowy-user/user_profile.pb.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'mobile_profile_banner.dart';

class MobileAccountProfile extends StatelessWidget {
  const MobileAccountProfile({super.key, required this.userProfile});

  final UserProfilePB userProfile;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context),
        spacing = theme.spacing,
        size = MediaQuery.of(context).size,
        bloc = context.read<ProfileSettingBloc>(),
        state = bloc.state,
        profile = state.profile,
        hasDescription = profile.aboutMe.isNotEmpty;

    return Stack(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding:
                  EdgeInsets.fromLTRB(spacing.xl, spacing.l, spacing.xl, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MobileProfileBanner(
                    size: Size(size.width, 92),
                    banner: profile.banner,
                  ),
                  VSpace(64),
                  Text(
                    profile.name,
                    style: theme.textStyle.heading3
                        .enhanced(color: theme.textColorScheme.primary),
                  ),
                  Text(
                    profile.email,
                    style: theme.textStyle.heading4
                        .standard(color: theme.textColorScheme.primary),
                  ),
                  if (hasDescription) ...[
                    VSpace(spacing.l),
                    context.buildDescription(textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
            AFDivider(spacing: spacing.m),
          ],
        ),
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 58),
            child: context.buildAvatar(),
          ),
        ),
      ],
    );
  }
}
