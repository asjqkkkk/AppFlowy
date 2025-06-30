import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/startup/tasks/device_info_task.dart';
import 'package:appflowy/workspace/application/user/settings_user_bloc.dart';
import 'package:appflowy/workspace/presentation/settings/pages/account/account_deletion.dart';
import 'package:appflowy/workspace/presentation/settings/widgets/account_and_app/password_button.dart';
import 'package:appflowy/workspace/presentation/settings/widgets/account_and_app/sign_in_out_button.dart';
import 'package:appflowy_backend/protobuf/flowy-user/user_profile.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/workspace.pb.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingsAccountView extends StatelessWidget {
  const SettingsAccountView({
    super.key,
    required this.userProfile,
    required this.didLogin,
    required this.didLogout,
  });

  final UserProfilePB userProfile;

  // Called when the user signs in from the setting dialog
  final VoidCallback didLogin;

  // Called when the user logout in the setting dialog
  final VoidCallback didLogout;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context),
        spacing = theme.spacing,
        xxl = spacing.xxl;
    return BlocProvider<SettingsUserViewBloc>(
      create: (context) => getIt<SettingsUserViewBloc>(param1: userProfile)
        ..add(const SettingsUserEvent.initial()),
      child: BlocBuilder<SettingsUserViewBloc, SettingsUserState>(
        builder: (context, state) {
          final isLocal = state.userProfile.userAuthType == AuthTypePB.Local;
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
                      if (!isLocal)
                        _commonLayout(
                          title:
                              LocaleKeys.settings_accountPage_email_title.tr(),
                          subtitle: userProfile.email,
                          context: context,
                        ),
                      if (!isLocal)
                        _commonLayout(
                          title: LocaleKeys.newSettings_myAccount_password_title
                              .tr(),
                          subtitle: LocaleKeys
                              .settings_accountPage_passwordDescription
                              .tr(),
                          context: context,
                          button:
                              PasswordButton(userProfile: state.userProfile),
                        ),
                      _commonLayout(
                        title: LocaleKeys.settings_accountPage_login_title.tr(),
                        subtitle: isLocal
                            ? LocaleKeys.settings_accountPage_loginDescription
                                .tr()
                            : LocaleKeys.settings_accountPage_logoutDescription
                                .tr(),
                        context: context,
                        button: SignInOutButton(
                          userProfile: state.userProfile,
                          onAction: isLocal ? didLogin : didLogout,
                          signIn: isLocal,
                        ),
                      ),
                      if (!isLocal)
                        _commonLayout(
                          title: LocaleKeys.button_deleteAccount.tr(),
                          subtitle: LocaleKeys
                              .settings_accountPage_deleteAccountDescription
                              .tr(),
                          context: context,
                          button: AccountDeletionButton(showDescription: false),
                        ),
                      VSpace(20),
                      AFDivider(color: theme.borderColorScheme.primary),
                      VSpace(20),
                      _commonLayout(
                        title:
                            LocaleKeys.newSettings_myAccount_aboutAppFlowy.tr(),
                        subtitle:
                            LocaleKeys.settings_accountPage_officialVersion.tr(
                          namedArgs: {
                            'version': ApplicationInfo.applicationVersion,
                          },
                        ),
                        context: context,
                      ),
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
      child: Text(
        LocaleKeys.newSettings_myAccount_title.tr(),
        style: theme.textStyle.heading2
            .enhanced(color: theme.textColorScheme.primary),
      ),
    );
  }

  Widget _commonLayout({
    required String title,
    required String subtitle,
    required BuildContext context,
    Widget? button,
  }) {
    final theme = AppFlowyTheme.of(context), spacing = theme.spacing;
    return Padding(
      padding: EdgeInsets.only(bottom: spacing.xxl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textStyle.body
                      .enhanced(color: theme.textColorScheme.primary),
                ),
                VSpace(spacing.xs),
                Text(
                  subtitle,
                  style: theme.textStyle.caption
                      .standard(color: theme.textColorScheme.secondary),
                ),
              ],
            ),
          ),
          if (button != null) ...[
            HSpace(spacing.m),
            button,
          ],
        ],
      ),
    );
  }
}
