import 'package:appflowy/features/workspace/logic/workspace_bloc.dart';
import 'package:appflowy/workspace/presentation/home/menu/sidebar/workspace_export_dialog.dart';
import 'package:appflowy/workspace/presentation/settings/shared/single_setting_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingsExportFileWidget extends StatefulWidget {
  const SettingsExportFileWidget({super.key});

  @override
  State<SettingsExportFileWidget> createState() =>
      SettingsExportFileWidgetState();
}

@visibleForTesting
class SettingsExportFileWidgetState extends State<SettingsExportFileWidget> {
  @override
  Widget build(BuildContext context) {
    return SingleSettingAction(
      label: 'Backup your workspace to AppFlowy workspace file (.zip)',
      labelMaxLines: 2,
      buttonLabel: 'Backup',
      onPressed: () async {
        final userWorkspaceBloc = context.read<UserWorkspaceBloc>();
        final currentWorkspace = userWorkspaceBloc.state.currentWorkspace;
        if (currentWorkspace == null) {
          return;
        }
        final workspaceType = currentWorkspace.workspaceType;
        await WorkspaceExportDialog.show(
          context: context,
          workspaceId: currentWorkspace.workspaceId,
          workspaceName: currentWorkspace.name,
          workspaceType: workspaceType,
        );
      },
    );
  }
}
