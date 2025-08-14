import 'package:appflowy/features/export/logic/workspace_export_bloc.dart';
import 'package:appflowy/features/workspace/logic/workspace_bloc.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
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
      listener: _onListener,
      child: SingleSettingAction(
        label: LocaleKeys.settings_files_backupWorkspaceLabel.tr(),
        labelMaxLines: 2,
        buttonLabel:
            LocaleKeys.workspaceImport_settings_backupWorkspace_buttonText.tr(),
        onPressed: () => _onExportPressed(context),
      ),
    );
  }

  void _onListener(BuildContext context, WorkspaceExportState state) {
    if (state.isExporting) {
      _showLoadingDialog(context);
    } else if (state.exportResult != null) {
      if (workspaceType == WorkspaceTypePB.Vault) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      state.exportResult!.fold(
        (_) {
          if (workspaceType == WorkspaceTypePB.Vault) {
            showToastNotification(
              context: context,
              message: LocaleKeys.settings_files_exportFileSuccess.tr(),
            );
          } else {
            _showLoadingCloudExportDialog(context);
          }
        },
        (error) {
          final message = error.msg.contains('404')
              ? 'This endpoint is not supported for your server.'
              : LocaleKeys.settings_files_exportFileFail.tr();
          showToastNotification(
            context: context,
            message: message,
            type: ToastificationType.error,
          );
        },
      );
    }
  }

  Future<void> _onExportPressed(BuildContext context) async {
    if (workspaceType == WorkspaceTypePB.Vault) {
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
    } else {
      context.read<WorkspaceExportBloc>().add(
            WorkspaceExportStartEvent(
              workspaceId: workspaceId,
              exportPath: '',
              exportName: '',
            ),
          );
    }
  }

  void _showLoadingDialog(BuildContext context) {
    if (workspaceType == WorkspaceTypePB.Vault) {
      _showLoadingLocalExportDialog(context);
    }
  }

  void _showLoadingLocalExportDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _LoadingLocalExportDialog(),
    );
  }

  void _showLoadingCloudExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _LoadingCloudExportDialog(),
    );
  }
}

class _LoadingCloudExportDialog extends StatelessWidget {
  const _LoadingCloudExportDialog();

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return AFModal(
      constraints: BoxConstraints.tight(const Size(400, 182)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AFModalHeader(
            leading: Text(
              'Backup in progress',
              style: theme.textStyle.heading4.prominent(
                color: theme.textColorScheme.primary,
              ),
            ),
            trailing: [
              AFGhostButton.normal(
                onTap: () => Navigator.of(context).pop(),
                padding: EdgeInsets.all(theme.spacing.xs),
                builder: (context, isHovering, disabled) {
                  return FlowySvg(
                    FlowySvgs.toast_close_s,
                    size: Size.square(20),
                  );
                },
              ),
            ],
          ),
          AFModalBody(
            child: Text(
              'We will send an email with download link once the export is complete.',
              style: theme.textStyle.body.standard(
                color: theme.textColorScheme.secondary,
              ),
            ),
          ),
          Spacer(),
          AFModalFooter(
            trailing: [
              AFFilledTextButton.primary(
                text: LocaleKeys.button_ok.tr(),
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingLocalExportDialog extends StatelessWidget {
  const _LoadingLocalExportDialog();

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
