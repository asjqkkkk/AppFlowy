import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

class WorkspaceImportButton extends StatelessWidget {
  const WorkspaceImportButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FlowyTooltip(
      message: 'Import Workspace',
      child: AFGhostTextButton.primary(
        onTap: onPressed,
        text: 'Import Workspace',
      ),
    );
  }
}
