import 'package:appflowy/features/share_tab/data/models/share_access_level.dart';
import 'package:appflowy/features/share_tab/data/models/shared_group.dart';
import 'package:appflowy/features/share_tab/presentation/widgets/access_level_list_widget.dart';
import 'package:appflowy/features/share_tab/presentation/widgets/edit_access_level_widget.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/workspace/presentation/home/menu/sidebar/workspace/_sidebar_workspace_icon.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/widget/flowy_tooltip.dart';
import 'package:flutter/material.dart';

class SharedGroupWidget extends StatelessWidget {
  const SharedGroupWidget({
    super.key,
    required this.group,
  });

  final SharedGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return AFMenuItem(
      cursor: SystemMouseCursors.basic,
      padding: EdgeInsets.symmetric(
        vertical: theme.spacing.s,
        horizontal: theme.spacing.m,
      ),
      leading: _buildLeading(context),
      title: _buildTitle(context),
      subtitle: _buildSubtitle(context),
      trailing: (context, isHovering, disabled) => _buildTrailing(
        context,
        isHovering,
        disabled,
      ),
      onTap: () {},
    );
  }

  Widget _buildLeading(BuildContext context) {
    return WorkspaceIcon(
      isEditable: false,
      workspaceIcon: group.icon,
      workspaceName: group.name,
      iconSize: 32.0,
      emojiSize: 24.0,
      fontSize: 16.0,
      onSelected: (r) {},
      borderRadius: 8.0,
      showBorder: false,
      figmaLineHeight: 24.0,
    );
  }

  Widget _buildTitle(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return Row(
      children: [
        Flexible(
          child: FlowyTooltip(
            message: group.name,
            child: Text(
              LocaleKeys.shareTab_anyoneAtWorkspace.tr(
                namedArgs: {
                  'workspace': group.name,
                },
              ),
              style: theme.textStyle.body.standard(
                color: theme.textColorScheme.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return Text(
      LocaleKeys.shareTab_anyoneInGroupWithLinkHasFullAccess.tr(),
      textAlign: TextAlign.left,
      style: theme.textStyle.caption.standard(
        color: theme.textColorScheme.secondary,
      ),
    );
  }

  Widget _buildTrailing(
    BuildContext context,
    bool isHovering,
    bool disabled,
  ) {
    return EditAccessLevelWidget(
      disabled: true,
      supportedAccessLevels: ShareAccessLevel.values,
      selectedAccessLevel: ShareAccessLevel.fullAccess,
      callbacks: AccessLevelListCallbacks.none(),
      additionalUserManagementOptions: [],
    );
  }
}
