import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class ImportHeader extends StatelessWidget {
  const ImportHeader({
    super.key,
    required this.onClose,
  });

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return AFModalHeader(
      leading: Text(
        LocaleKeys.workspaceImport_dialogTitle.tr(),
        style: theme.textStyle.heading4.prominent(
          color: theme.textColorScheme.primary,
        ),
      ),
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
    );
  }
}
