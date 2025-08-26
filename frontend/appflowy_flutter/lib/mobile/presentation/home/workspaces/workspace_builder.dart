import 'package:appflowy/features/workspace/data/repositories/rust_workspace_repository_impl.dart';
import 'package:appflowy/features/workspace/logic/workspace_bloc.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/widgets/flowy_mobile_state_container.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/user/application/auth/auth_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

typedef UserWorkspaceBlocBuilder = Widget Function(
  BuildContext context,
  UserWorkspaceBloc bloc,
);

class WorkspaceBuilder extends StatelessWidget {
  const WorkspaceBuilder({super.key, required this.builder});
  final UserWorkspaceBlocBuilder builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: getIt<AuthService>().getUser(),
      builder: (context, snapshot) {
        String? errorMsg;
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        final userProfile = snapshot.data?.fold(
          (userProfile) {
            return userProfile;
          },
          (error) {
            errorMsg = error.msg;
            return null;
          },
        );
        if (userProfile == null) return _buildErrorWidget(errorMsg);

        return BlocProvider(
          create: (context) => UserWorkspaceBloc(
            userProfile: userProfile,
            repository: RustWorkspaceRepositoryImpl(
              userId: userProfile.id,
            ),
          )..add(UserWorkspaceEvent.initialize()),
          child: BlocBuilder<UserWorkspaceBloc, UserWorkspaceState>(
            builder: (context, state) {
              return builder(
                context,
                context.read<UserWorkspaceBloc>(),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget(String? errorMsg) {
    return FlowyMobileStateContainer.error(
      emoji: '🛸',
      title: LocaleKeys.settings_mobile_userprofileError.tr(),
      description: LocaleKeys.settings_mobile_userprofileErrorDescription.tr(),
      errorMsg: errorMsg,
    );
  }
}
