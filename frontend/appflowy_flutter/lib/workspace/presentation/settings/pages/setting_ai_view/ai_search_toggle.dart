import 'package:appflowy/features/workspace/logic/workspace_bloc.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/workspace/application/settings/ai/settings_ai_bloc.dart';
import 'package:appflowy/workspace/presentation/widgets/toggle/toggle.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AISearchToggle extends StatelessWidget {
  const AISearchToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            FlowyText.medium(
              LocaleKeys.settings_aiPage_keys_enableAISearchTitle.tr(),
            ),
            const Spacer(),
            BlocBuilder<SettingsAIBloc, SettingsAIState>(
              builder: (context, state) {
                final isLocalWorkspace = context
                        .read<UserWorkspaceBloc>()
                        .state
                        .currentWorkspace
                        ?.workspaceType ==
                    WorkspaceTypePB.Vault;
                final isDisabled = isLocalWorkspace && !state.isLocalAIEnabled;

                if (state.aiSettings == null) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: SizedBox(
                      height: 26,
                      width: 26,
                      child: CircularProgressIndicator.adaptive(),
                    ),
                  );
                } else {
                  return Opacity(
                    opacity: isDisabled ? 0.5 : 1.0,
                    child: IgnorePointer(
                      ignoring: isDisabled,
                      child: Toggle(
                        value: !isDisabled && state.enableSearchIndexing,
                        onChanged: (_) => context
                            .read<SettingsAIBloc>()
                            .add(const SettingsAIEvent.toggleAISearch()),
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
