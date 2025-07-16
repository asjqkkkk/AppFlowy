import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/mobile_toolbar_v3/aa_menu/_toolbar_theme.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/plugins.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

class IndentAndOutdentItems extends StatelessWidget {
  const IndentAndOutdentItems({
    super.key,
    required this.service,
    required this.editorState,
  });

  final EditorState editorState;
  final AppFlowyMobileToolbarWidgetService service;

  @override
  Widget build(BuildContext context) {
    final theme = ToolbarColorExtension.of(context);
    final enableIndent = isIndentable(editorState);
    final enableOutdent = isOutdentable(editorState);

    return IntrinsicHeight(
      child: Row(
        children: [
          MobileToolbarMenuItemWrapper(
            size: const Size(95, 52),
            icon: FlowySvg(
              FlowySvgs.m_aa_outdent_m,
              color: enableOutdent
                  ? theme.toolbarMenuIconColor
                  : theme.toolbarMenuIconDisabledColor,
            ),
            enable: enableOutdent,
            isSelected: false,
            enableTopRightRadius: false,
            enableBottomRightRadius: false,
            iconPadding: const EdgeInsets.symmetric(vertical: 14.0),
            backgroundColor: theme.toolbarMenuItemBackgroundColor,
            onTap: () {
              service.closeItemMenu();
              outdentCommand.execute(editorState);
            },
          ),
          const ScaledVerticalDivider(),
          MobileToolbarMenuItemWrapper(
            size: const Size(95, 52),
            icon: FlowySvg(
              FlowySvgs.m_aa_indent_m,
              color: enableIndent
                  ? theme.toolbarMenuIconColor
                  : theme.toolbarMenuIconDisabledColor,
            ),
            enable: enableIndent,
            isSelected: false,
            enableTopLeftRadius: false,
            enableBottomLeftRadius: false,
            iconPadding: const EdgeInsets.symmetric(vertical: 14.0),
            backgroundColor: theme.toolbarMenuItemBackgroundColor,
            onTap: () {
              service.closeItemMenu();
              indentCommand.execute(editorState);
            },
          ),
        ],
      ),
    );
  }
}
