import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/user/application/password/password_bloc.dart';
import 'package:appflowy/user/application/sign_in_bloc.dart';
import 'package:appflowy/workspace/presentation/settings/pages/account/password/change_password.dart';
import 'package:appflowy/workspace/presentation/settings/pages/account/password/setup_password.dart';
import 'package:appflowy_backend/protobuf/flowy-user/user_profile.pb.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PasswordButton extends StatelessWidget {
  const PasswordButton({super.key, required this.userProfile});

  final UserProfilePB userProfile;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<PasswordBloc>(), state = bloc.state;
    return state.hasPassword
        ? AFOutlinedTextButton.normal(
            text: LocaleKeys.newSettings_myAccount_password_changePassword.tr(),
            onTap: () => _showChangePasswordDialog(context),
          )
        : AFOutlinedTextButton.normal(
            text: LocaleKeys.newSettings_myAccount_password_setupPassword.tr(),
            onTap: () => _showSetPasswordDialog(context),
          );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final theme = AppFlowyTheme.of(context);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider<PasswordBloc>.value(
            value: context.read<PasswordBloc>(),
          ),
          BlocProvider<SignInBloc>.value(
            value: getIt<SignInBloc>(),
          ),
        ],
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(theme.borderRadius.xl),
          ),
          child: ChangePasswordDialogContent(userProfile: userProfile),
        ),
      ),
    );
  }

  Future<void> _showSetPasswordDialog(BuildContext context) async {
    final theme = AppFlowyTheme.of(context);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider<PasswordBloc>.value(
            value: context.read<PasswordBloc>(),
          ),
          BlocProvider<SignInBloc>.value(
            value: getIt<SignInBloc>(),
          ),
        ],
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(theme.borderRadius.xl),
          ),
          child: SetupPasswordDialogContent(
            userProfile: userProfile,
          ),
        ),
      ),
    );
  }
}
