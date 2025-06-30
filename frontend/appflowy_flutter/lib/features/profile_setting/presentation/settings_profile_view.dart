import 'package:appflowy/features/profile_setting/logic/profile_setting_bloc.dart';
import 'package:appflowy/features/profile_setting/logic/profile_setting_event.dart';
import 'package:appflowy/features/profile_setting/logic/profile_setting_state.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/features/profile_setting/presentation/widgets/banner_selector.dart';
import 'package:appflowy_backend/protobuf/flowy-user/user_profile.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/workspace.pbenum.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'widgets/profile_about_me.dart';
import 'widgets/profile_display_name.dart';
import 'widgets/preview_button.dart';
import 'widgets/profile_avatar.dart';

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
    final theme = AppFlowyTheme.of(context),
        spacing = theme.spacing,
        xxl = spacing.xxl,
        isLocal = userProfile.workspaceType == WorkspaceTypePB.LocalW;
    return BlocProvider(
      create: (context) => ProfileSettingBloc(
        userProfile: userProfile,
        workspace: workspace,
      )..add(ProfileSettingEvent.initial()),
      child: BlocBuilder<ProfileSettingBloc, ProfileSettingState>(
        builder: (context, state) {
          if (state.profile.id.isEmpty) {
            return Center(child: CircularProgressIndicator.adaptive());
          }
          return SingleChildScrollView(
            physics: ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                buildTitle(context),
                AFDivider(color: theme.borderColorScheme.primary),
                Padding(
                  padding: EdgeInsets.all(xxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      buildAvatarAndName(context),
                      if (!isLocal) ...[
                        VSpace(spacing.xxl),
                        buildAboutMe(context),
                        VSpace(spacing.xxl),
                        BannerImages(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget buildTitle(BuildContext context) {
    final theme = AppFlowyTheme.of(context),
        spacing = theme.spacing,
        xxl = spacing.xxl;
    return Padding(
      padding: EdgeInsets.fromLTRB(xxl, 28, xxl, xxl),
      child: Row(
        children: [
          Text(
            LocaleKeys.settings_profilePage_title.tr(),
            style: theme.textStyle.heading2
                .enhanced(color: theme.textColorScheme.primary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Spacer(),
          PreviewButton(),
        ],
      ),
    );
  }

  Widget buildAvatarAndName(BuildContext context) {
    final theme = AppFlowyTheme.of(context),
        spacing = theme.spacing,
        state = context.read<ProfileSettingBloc>().state;
    final name = state.profile.name;
    return SizedBox(
      height: 80,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProfileAvatar(),
          HSpace(spacing.xxl),
          Flexible(child: ProfileDisplayName(name: name)),
        ],
      ),
    );
  }

  Widget buildAboutMe(BuildContext context) {
    final state = context.read<ProfileSettingBloc>().state,
        aboutMe = state.profile.aboutMe;
    return ProfileAboutMe(aboutMe: aboutMe);
  }
}
