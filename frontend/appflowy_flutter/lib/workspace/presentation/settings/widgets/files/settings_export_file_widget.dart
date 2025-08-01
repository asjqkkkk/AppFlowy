import 'package:appflowy/features/export/logic/workspace_export_bloc.dart';
import 'package:appflowy/features/workspace/logic/workspace_bloc.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/workspace/presentation/settings/shared/single_setting_action.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy_backend/protobuf/flowy-user/workspace.pbenum.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingsExportFileWidget extends StatelessWidget {
  const SettingsExportFileWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final userWorkspaceBloc = context.read<UserWorkspaceBloc>();
    final currentWorkspace = userWorkspaceBloc.state.currentWorkspace;

    if (currentWorkspace == null) {
      return const SizedBox.shrink();
    }

    return BlocProvider(
      create: (_) =>
          WorkspaceExportBloc(workspaceId: currentWorkspace.workspaceId),
      child: _ExportWidget(
        workspaceId: currentWorkspace.workspaceId,
        workspaceName: currentWorkspace.name,
        workspaceType: currentWorkspace.workspaceType,
      ),
    );
  }
}

class _ExportWidget extends StatelessWidget {
  const _ExportWidget({
    required this.workspaceId,
    required this.workspaceName,
    required this.workspaceType,
  });

  final String workspaceId;
  final String workspaceName;
  final WorkspaceTypePB workspaceType;

  @override
  Widget build(BuildContext context) {
    return BlocListener<WorkspaceExportBloc, WorkspaceExportState>(
      listener: (context, state) {
        if (state.isExporting) {
          _showLoadingDialog(context);
        } else if (state.exportResult != null) {
          Navigator.of(context, rootNavigator: true).pop();
          state.exportResult!.fold(
            (_) {
              showToastNotification(
                context: context,
                message: LocaleKeys.settings_files_exportFileSuccess.tr(),
              );
            },
            (error) {
              showToastNotification(
                context: context,
                message: LocaleKeys.settings_files_exportFileFail.tr(),
                description: error.msg,
                type: ToastificationType.error,
              );
            },
          );
        }
      },
      child: SingleSettingAction(
        label: LocaleKeys.settings_files_backupWorkspaceLabel.tr(),
        labelMaxLines: 2,
        buttonLabel:
            LocaleKeys.workspaceImport_settings_backupWorkspace_buttonText.tr(),
        onPressed: workspaceType == WorkspaceTypePB.Vault
            ? () => _onExportPressed(context)
            : () => showToastNotification(
                  context: context,
                  type: ToastificationType.error,
                  message:
                      LocaleKeys.settings_files_cloudWorkspaceNotSupported.tr(),
                ),
      ),
    );
  }

  Future<void> _onExportPressed(BuildContext context) async {
    final String? selectedDirectory =
        await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory == null || !context.mounted) {
      return;
    }

    final exportName =
        '${workspaceName}_${DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now())}.zip';

    context.read<WorkspaceExportBloc>().add(
          WorkspaceExportStartEvent(
            workspaceId: workspaceId,
            exportPath: '$selectedDirectory/$exportName',
            exportName: exportName,
          ),
        );
  }

  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _LoadingExportDialog(),
    );
  }
}

class _LoadingExportDialog extends StatelessWidget {
  const _LoadingExportDialog();

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return AFModal(
      constraints: BoxConstraints.tight(const Size(400, 182)),
      child: AFModalBody(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                ),
              ),
              VSpace(theme.spacing.xxl),
              Text(
                LocaleKeys.settings_files_backingUpWorkspace.tr(),
                style: theme.textStyle.heading4.prominent(
                  color: theme.textColorScheme.primary,
                ),
              ),
              VSpace(theme.spacing.m),
              Text(
                LocaleKeys.settings_files_doNotQuitApp.tr(),
                style: theme.textStyle.body.standard(
                  color: theme.textColorScheme.secondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
