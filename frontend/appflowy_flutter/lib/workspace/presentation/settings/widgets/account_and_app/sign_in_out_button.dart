import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/user/application/auth/auth_service.dart';
import 'package:appflowy/user/application/sign_in_bloc.dart';
import 'package:appflowy/workspace/presentation/settings/pages/account/account_sign_in_out.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy_backend/protobuf/flowy-user/user_profile.pb.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SignInOutButton extends StatelessWidget {
  const SignInOutButton({
    super.key,
    required this.userProfile,
    required this.onAction,
    this.signIn = true,
  });

  final UserProfilePB userProfile;
  final VoidCallback onAction;
  final bool signIn;

  @override
  Widget build(BuildContext context) {
    return AFOutlinedTextButton.normal(
      text: signIn
          ? LocaleKeys.settings_accountPage_login_loginLabel.tr()
          : LocaleKeys.settings_accountPage_login_logoutLabel.tr(),
      onTap: () =>
          signIn ? _showSignInDialog(context) : _showLogoutDialog(context),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showCancelAndConfirmDialog(
      context: context,
      title: LocaleKeys.settings_accountPage_login_logoutLabel.tr(),
      description: LocaleKeys.settings_menu_logoutPrompt.tr(),
      confirmLabel: LocaleKeys.button_yes.tr(),
      onConfirm: (_) async {
        await getIt<AuthService>().signOut();
        onAction();
      },
    );
  }

  Future<void> _showSignInDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => BlocProvider<SignInBloc>(
        create: (context) => getIt<SignInBloc>(),
        child: const FlowyDialog(
          constraints: BoxConstraints(maxHeight: 485, maxWidth: 375),
          child: SignInDialogContent(),
        ),
      ),
    );
  }
}
