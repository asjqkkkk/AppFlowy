import 'package:appflowy/features/export/logic/workspace_export_bloc.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy_backend/protobuf/flowy-user/workspace.pbenum.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WorkspaceExportDialog extends StatelessWidget {
  const WorkspaceExportDialog({
    super.key,
    required this.workspaceId,
    required this.workspaceName,
    required this.workspaceType,
  });

  final String workspaceId;
  final String workspaceName;
  final WorkspaceTypePB workspaceType;

  static Future<void> show({
    required BuildContext context,
    required String workspaceId,
    required String workspaceName,
    required WorkspaceTypePB workspaceType,
  }) async {
    await showDialog(
      context: context,
      builder: (_) => BlocProvider(
        create: (_) => WorkspaceExportBloc(workspaceId: workspaceId)
          ..add(WorkspaceExportInitialEvent(workspaceId: workspaceId)),
        child: WorkspaceExportDialog(
          workspaceId: workspaceId,
          workspaceName: workspaceName,
          workspaceType: workspaceType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FlowyDialog(
      constraints: BoxConstraints.tight(const Size(360, 240)),
      child: BlocConsumer<WorkspaceExportBloc, WorkspaceExportState>(
        listener: (context, state) {
          if (state.exportResult != null) {
            state.exportResult!.fold(
              (_) {
                // Success
                showToastNotification(
                  context: context,
                  message: LocaleKeys.settings_files_exportFileSuccess.tr(),
                );
                Navigator.of(context).pop();
              },
              (error) {
                // Failure
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
        builder: (context, state) {
          final theme = AppFlowyTheme.of(context);

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    HSpace(4.0),
                    Expanded(
                      child: Text(
                        'Backup your workspace',
                        style: theme.textStyle.heading4.enhanced(
                          color: theme.textColorScheme.primary,
                        ),
                      ),
                    ),
                    FlowyIconButton(
                      icon: const FlowySvg(
                        FlowySvgs.toast_close_s,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const VSpace(20),

                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Please don\'t quit the app until the backup file is created.',
                        style: theme.textStyle.body.standard(
                          color: theme.textColorScheme.primary,
                        ),
                        maxLines: 3,
                      ),

                      // Progress indicator
                      if (state.isExporting) ...[
                        const Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        const VSpace(4),
                        Center(
                          child: Text(
                            'Exporting...',
                            style: theme.textStyle.body.standard(
                              color: theme.textColorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                Spacer(),

                // Actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AFGhostTextButton.primary(
                        text: LocaleKeys.button_cancel.tr(),
                        onTap: () {
                          if (!state.isExporting) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                      const HSpace(8),
                      workspaceType == WorkspaceTypePB.Vault
                          ? AFFilledTextButton.primary(
                              text: LocaleKeys.settings_files_export.tr(),
                              onTap: () => _onExportPressed(context),
                            )
                          : FlowyTooltip(
                              message:
                                  'Cloud workspace is not supported yet (coming soon)',
                              child: AFFilledTextButton.disabled(
                                text: LocaleKeys.settings_files_export.tr(),
                              ),
                            ),
                    ],
                  ),
                ),
                const VSpace(8),
              ],
            ),
          );
        },
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
}
