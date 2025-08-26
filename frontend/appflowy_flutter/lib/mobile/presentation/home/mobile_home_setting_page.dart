import 'package:appflowy/env/cloud_env.dart';
import 'package:appflowy/env/env.dart';
import 'package:appflowy/features/profile_setting/logic/profile_setting_bloc.dart';
import 'package:appflowy/features/profile_setting/logic/profile_setting_event.dart';
import 'package:appflowy/features/profile_setting/logic/profile_setting_state.dart';
import 'package:appflowy/features/profile_setting/presentation/widgets/mobile/mobile_account_profile.dart';
import 'package:appflowy/features/workspace/workspace.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/base/app_bar/app_bar.dart';
import 'package:appflowy/mobile/presentation/presentation.dart';
import 'package:appflowy/mobile/presentation/setting/ai/ai_settings_group.dart';
import 'package:appflowy/mobile/presentation/setting/cloud/cloud_setting_group.dart';
import 'package:appflowy/mobile/presentation/setting/user_session_setting_group.dart';
import 'package:appflowy/mobile/presentation/setting/workspace/workspace_setting_group.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'workspaces/workspace_builder.dart';

class MobileHomeSettingPage extends StatelessWidget {
  const MobileHomeSettingPage({
    super.key,
    this.profileSettingBloc,
  });

  static const routeName = '/settings';
  final ProfileSettingBloc? profileSettingBloc;

  @override
  Widget build(BuildContext context) {
    return WorkspaceBuilder(
      builder: (context, bloc) {
        return Scaffold(
          appBar: FlowyAppBar(
            titleText: LocaleKeys.settings_title.tr(),
            showDivider: false,
          ),
          body: _buildSettingsWidget(bloc.userProfile, profileSettingBloc),
        );
      },
    );
  }

  Widget _buildSettingsWidget(
    UserProfilePB userProfile,
    ProfileSettingBloc? profileSettingBloc,
  ) {
    return BlocBuilder<UserWorkspaceBloc, UserWorkspaceState>(
      builder: (context, state) {
        final currentWorkspaceId = state.currentWorkspace?.workspaceId ?? '';
        final child = BlocBuilder<ProfileSettingBloc, ProfileSettingState>(
          builder: (context, profileState) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  if (state.userProfile.userAuthType == AuthTypePB.Server)
                    MobileAccountProfile(),
                  PersonalInfoSettingGroup(userProfile: userProfile),
                  if (state.userProfile.userAuthType == AuthTypePB.Server)
                    const WorkspaceSettingGroup(),
                  const AppearanceSettingGroup(),
                  LanguageAndTimeDateSettingGroup(
                    userProfile: state.userProfile,
                  ),
                  if (Env.enableCustomCloud) const CloudSettingGroup(),
                  if (isAuthEnabled)
                    AiSettingsGroup(
                      key: ValueKey(currentWorkspaceId),
                      userProfile: userProfile,
                      workspaceId: currentWorkspaceId,
                    ),
                  const SupportSettingGroup(),
                  const AboutSettingGroup(),
                  UserSessionSettingGroup(
                    userProfile: userProfile,
                    showThirdPartyLogin: false,
                  ),
                  const VSpace(20),
                ],
              ),
            );
          },
        );
        if (profileSettingBloc != null) {
          return BlocProvider.value(
            value: profileSettingBloc,
            child: child,
          );
        } else {
          return BlocProvider(
            create: (context) => ProfileSettingBloc(
              userProfile: userProfile,
              workspaceId: currentWorkspaceId,
            )..add(ProfileSettingEvent.initial()),
            child: child,
          );
        }
      },
    );
  }
}
