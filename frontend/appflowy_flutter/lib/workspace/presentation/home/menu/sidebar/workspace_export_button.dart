import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

class WorkspaceExportButton extends StatelessWidget {
  const WorkspaceExportButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FlowyTooltip(
      message: LocaleKeys.settings_files_exportData.tr(),
      child: AFGhostTextButton.primary(
        onTap: onPressed,
        text: 'Export Workspace',
      ),
    );
  }
}
