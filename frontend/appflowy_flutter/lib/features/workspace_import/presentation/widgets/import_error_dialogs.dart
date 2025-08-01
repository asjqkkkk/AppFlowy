import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class FileSizeLimitExceededDialog extends StatelessWidget {
  const FileSizeLimitExceededDialog({
    super.key,
    required this.fileName,
    required this.sizeLimit,
  });

  final String fileName;
  final String sizeLimit;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return AFModal(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AFModalHeader(
            leading:
                Text(LocaleKeys.workspaceImport_fileSizeLimitExceeded.tr()),
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
              LocaleKeys.workspaceImport_fileSizeLimitExceededMessage.tr(
                args: [fileName, sizeLimit],
              ),
            ),
          ),
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

class InvalidFileFormatDialog extends StatelessWidget {
  const InvalidFileFormatDialog({
    super.key,
    required this.fileName,
  });

  final String fileName;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return AFModal(
      constraints: const BoxConstraints(
        minWidth: 400,
        maxWidth: 400,
        minHeight: 182,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AFModalHeader(
            leading: Text(LocaleKeys.workspaceImport_invalidFileFormat.tr()),
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
              LocaleKeys.workspaceImport_invalidFileFormatMessage.tr(
                args: [fileName],
              ),
            ),
          ),
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
