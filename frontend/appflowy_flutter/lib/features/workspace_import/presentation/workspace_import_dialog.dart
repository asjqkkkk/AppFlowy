import 'package:appflowy/features/workspace_import/data/models/import_error.dart';
import 'package:appflowy/features/workspace_import/data/repositories/rust_workspace_import_repository_impl.dart';
import 'package:appflowy/features/workspace_import/logic/workspace_import_dialog_bloc.dart';
import 'package:appflowy/features/workspace_import/presentation/widgets/import_description.dart';
import 'package:appflowy/features/workspace_import/presentation/widgets/import_dropzone.dart';
import 'package:appflowy/features/workspace_import/presentation/widgets/import_error_dialogs.dart';
import 'package:appflowy/features/workspace_import/presentation/widgets/import_header.dart';
import 'package:appflowy/features/workspace_import/presentation/widgets/unified_progress_dialog.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/document/presentation/editor_drop_manager.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WorkspaceImportDialog extends StatefulWidget {
  const WorkspaceImportDialog({
    super.key,
  });

  static Future<void> show(BuildContext context) async {
    enableDocumentDragNotifier.value = false;

    try {
      await showDialog(
        context: context,
        builder: (dialogContext) => BlocProvider(
          create: (context) => WorkspaceImportDialogBloc(
            importRepository: RustWorkspaceImportRepositoryImpl(),
          )..add(const WorkspaceImportDialogInitialized()),
          child: const WorkspaceImportDialog(),
        ),
      );
    } finally {
      enableDocumentDragNotifier.value = true;
    }
  }

  @override
  State<WorkspaceImportDialog> createState() => _WorkspaceImportDialogState();
}

class _WorkspaceImportDialogState extends State<WorkspaceImportDialog> {
  bool _hasProgressDialog = false;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return BlocConsumer<WorkspaceImportDialogBloc, WorkspaceImportDialogState>(
      listener: (context, state) {
        if (state.status == WorkspaceImportDialogStatus.success) {
          // do nothing
        } else if (state.status == WorkspaceImportDialogStatus.error &&
            state.error != null) {
          _showErrorDialog(context, state);
        } else if ((state.status == WorkspaceImportDialogStatus.uploading ||
                state.status == WorkspaceImportDialogStatus.importProgress) &&
            !_hasProgressDialog) {
          _showUnifiedProgressDialog(context);
        }
      },
      builder: (context, state) {
        return AFModal(
          constraints: const BoxConstraints(
            maxWidth: 600,
            minHeight: 306,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ImportHeader(
                onClose: () => Navigator.of(context).pop(),
              ),
              const ImportDescription(),
              const ImportDropzone(),
              VSpace(theme.spacing.xxl),
            ],
          ),
        );
      },
    );
  }

  void _showErrorDialog(
    BuildContext context,
    WorkspaceImportDialogState state,
  ) {
    final error = state.error!;

    switch (error.code) {
      case ImportErrorCode.fileSizeExceeded:
        showDialog(
          context: context,
          builder: (_) => FileSizeLimitExceededDialog(
            fileName:
                error.fileName ?? LocaleKeys.workspaceImport_unknownFile.tr(),
            sizeLimit: error.maxSizeLimit ??
                LocaleKeys.workspaceImport_sizeLimit200MB.tr(),
          ),
        );
        break;
      case ImportErrorCode.invalidFileFormat:
      case ImportErrorCode.fileNotFound:
      case ImportErrorCode.fileEmpty:
        showDialog(
          context: context,
          builder: (_) => InvalidFileFormatDialog(
            fileName:
                error.fileName ?? LocaleKeys.workspaceImport_unknownFile.tr(),
          ),
        );
        break;
      case ImportErrorCode.importFailed:
      case ImportErrorCode.unknown:
        showDialog(
          context: context,
          builder: (_) => InvalidFileFormatDialog(
            fileName:
                error.fileName ?? LocaleKeys.workspaceImport_unknownFile.tr(),
          ),
        );
        break;
    }
  }

  void _showUnifiedProgressDialog(BuildContext context) {
    _hasProgressDialog = true;
    showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<WorkspaceImportDialogBloc>(),
        child: const UnifiedProgressDialog(),
      ),
    ).then((_) {
      _hasProgressDialog = false;
    });
  }
}
