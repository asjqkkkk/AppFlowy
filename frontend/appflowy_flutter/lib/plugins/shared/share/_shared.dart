import 'package:appflowy/features/page_access_level/logic/page_access_level_bloc.dart';
import 'package:appflowy/features/share_tab/data/models/models.dart';
import 'package:appflowy/features/share_tab/logic/share_tab_bloc.dart';
import 'package:appflowy/features/workspace/logic/workspace_bloc.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/database/application/tab_bar_bloc.dart';
import 'package:appflowy/plugins/document/presentation/editor_notification.dart';
import 'package:appflowy/plugins/shared/share/share_bloc.dart';
import 'package:appflowy/plugins/shared/share/share_menu.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

class ShareMenuButton extends StatefulWidget {
  const ShareMenuButton({
    super.key,
    required this.tabs,
  });

  final List<ShareMenuTab> tabs;

  @override
  State<ShareMenuButton> createState() => _ShareMenuButtonState();
}

class _ShareMenuButtonState extends State<ShareMenuButton> {
  final popoverController = AFPopoverController();
  final popoverGroupId = SharePopoverGroupId();

  bool isShowingDialog = false;

  @override
  void initState() {
    super.initState();

    popoverController.addListener(() {
      if (context.mounted && popoverController.isOpen) {
        context.read<ShareBloc>().add(const ShareEvent.updatePublishStatus());
      }
    });
  }

  @override
  void dispose() {
    popoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shareBloc = context.read<ShareBloc>();
    final databaseBloc = context.read<DatabaseTabBarBloc?>();
    final userWorkspaceBloc = context.read<UserWorkspaceBloc>();
    final shareWithUserBloc = context.read<ShareTabBloc>();
    final pageAccessLevelBloc = context.read<PageAccessLevelBloc>();

    final buttonText =
        userWorkspaceBloc.state.currentWorkspace?.workspaceType ==
                WorkspaceTypePB.LocalW
            ? LocaleKeys.shareAction_buttonTextLocal.tr()
            : LocaleKeys.shareAction_buttonText.tr();

    return BlocBuilder<ShareBloc, ShareState>(
      builder: (context, state) {
        return AFPopover(
          controller: popoverController,
          groupId: popoverGroupId,
          anchor: AFAnchorAuto(
            offset: const Offset(-176, 12),
          ),
          canClose: (context) {
            return !isShowingDialog;
          },
          popover: (_) {
            return ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 460,
              ),
              child: MultiBlocProvider(
                providers: [
                  if (databaseBloc != null)
                    BlocProvider.value(
                      value: databaseBloc,
                    ),
                  BlocProvider.value(value: shareBloc),
                  BlocProvider.value(value: userWorkspaceBloc),
                  BlocProvider.value(value: shareWithUserBloc),
                  BlocProvider.value(value: pageAccessLevelBloc),
                ],
                child: Provider.value(
                  value: popoverGroupId,
                  child: ShareMenu(
                    tabs: widget.tabs,
                    viewName: state.viewName,
                    showDialogCallback: (value) {
                      isShowingDialog = value;
                    },
                    onClose: () {
                      popoverController.hide();
                    },
                  ),
                ),
              ),
            );
          },
          child: AFFilledTextButton.primary(
            text: buttonText,
            onTap: () {
              popoverController.show();

              /// Fetch the shared users when the popover is shown
              context.read<ShareTabBloc>().add(ShareTabEvent.loadSharedUsers());

              /// Fetch the subscription info
              context.read<UserWorkspaceBloc>().add(
                    UserWorkspaceEvent.fetchWorkspaceSubscriptionInfo(
                      workspaceId: state.workspaceId,
                    ),
                  );

              EditorNotification.exitEditing().post();
            },
          ),
        );
      },
    );
  }
}
