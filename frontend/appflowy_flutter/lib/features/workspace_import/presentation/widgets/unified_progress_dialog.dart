import 'package:appflowy/features/workspace_import/logic/workspace_import_dialog_bloc.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class UnifiedProgressDialog extends StatelessWidget {
  const UnifiedProgressDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return BlocBuilder<WorkspaceImportDialogBloc, WorkspaceImportDialogState>(
      builder: (context, state) {
        if (state.status == WorkspaceImportDialogStatus.uploading) {
          return AFModal(
            constraints: BoxConstraints.tight(const Size(400, 182)),
            child: AFModalBody(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(
                      dimension: 26,
                      child: const CircularProgressIndicator(),
                    ),
                    VSpace(theme.spacing.xxl),
                    Text(
                      LocaleKeys.workspaceImport_uploadingFile.tr(),
                      style: theme.textStyle.body.enhanced(
                        color: theme.textColorScheme.primary,
                      ),
                    ),
                    VSpace(theme.spacing.m),
                    Text(
                      LocaleKeys.workspaceImport_pleaseDoNotQuit.tr(),
                      style: theme.textStyle.body.standard(
                        color: theme.textColorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (state.status == WorkspaceImportDialogStatus.importProgress ||
            state.status == WorkspaceImportDialogStatus.success) {
          return AFModal(
            constraints: BoxConstraints.tight(const Size(400, 182)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AFModalHeader(
                  leading:
                      Text(LocaleKeys.workspaceImport_importInProgress.tr()),
                  trailing: [
                    AFGhostButton.normal(
                      onTap: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.all(theme.spacing.xs),
                      builder: (context, isHovering, disabled) {
                        return Center(
                          child: FlowySvg(
                            FlowySvgs.toast_close_s,
                            size: Size.square(20),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                AFModalBody(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        LocaleKeys
                            .workspaceImport_importConfirmationEmailMessage
                            .tr(),
                        style: theme.textStyle.body.standard(
                          color: theme.textColorScheme.primary,
                        ),
                      ),
                      SizedBox(height: theme.spacing.l),
                    ],
                  ),
                ),
                AFModalFooter(
                  trailing: [
                    AFFilledTextButton.primary(
                      text: LocaleKeys.button_ok.tr(),
                      onTap: () => Navigator.of(context)
                        ..pop()
                        ..pop(),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
