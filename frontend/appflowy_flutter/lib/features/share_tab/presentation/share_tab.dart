import 'package:appflowy/features/page_access_level/logic/page_access_level_bloc.dart';
import 'package:appflowy/features/share_tab/data/models/models.dart';
import 'package:appflowy/features/share_tab/data/models/shared_group.dart';
import 'package:appflowy/features/share_tab/logic/share_tab_bloc.dart';
import 'package:appflowy/features/share_tab/presentation/widgets/copy_link_widget.dart';
import 'package:appflowy/features/share_tab/presentation/widgets/general_access_section.dart';
import 'package:appflowy/features/share_tab/presentation/widgets/people_with_access_section.dart';
import 'package:appflowy/features/share_tab/presentation/widgets/share_with_user_widget.dart';
import 'package:appflowy/features/share_tab/presentation/widgets/upgrade_to_pro_widget.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/copy_and_paste/clipboard_service.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/workspace/presentation/home/menu/sidebar/space/shared_widget.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy_backend/protobuf/flowy-error/code.pbenum.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ShareTab extends StatefulWidget {
  const ShareTab({
    super.key,
    required this.workspaceId,
    required this.pageId,
    required this.workspaceName,
    required this.workspaceIcon,
    required this.isInProPlan,
    required this.onUpgradeToPro,
    required this.showDialogCallback,
  });

  final String workspaceId;
  final String pageId;

  // these 2 values should be provided by the share tab bloc
  final String workspaceName;
  final String workspaceIcon;

  final bool isInProPlan;
  final VoidCallback onUpgradeToPro;
  final void Function(bool value) showDialogCallback;

  @override
  State<ShareTab> createState() => _ShareTabState();
}

class _ShareTabState extends State<ShareTab> {
  final TextEditingController controller = TextEditingController();
  late final ShareTabBloc shareTabBloc;

  @override
  void initState() {
    super.initState();

    shareTabBloc = context.read<ShareTabBloc>();
  }

  @override
  void dispose() {
    controller.dispose();
    shareTabBloc.add(ShareTabEvent.clearState());

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return BlocConsumer<ShareTabBloc, ShareTabState>(
      listener: (context, state) async {
        await _onListenShareWithUserState(context, state);
      },
      builder: (context, state) {
        if (state.isLoading) {
          return const SizedBox.shrink();
        }

        final currentUser = state.currentUser;
        final accessLevel = context
                .read<PageAccessLevelBloc?>()
                ?.state
                .accessLevel ??
            state.users
                .firstWhereOrNull((user) => user.email == currentUser?.email)
                ?.accessLevel;
        final isFullAccess = accessLevel == ShareAccessLevel.fullAccess;
        String tooltip = '';
        if (!widget.isInProPlan) {
          tooltip = LocaleKeys.shareTab_upgradeToProToInviteGuests.tr();
        } else if (!isFullAccess) {
          tooltip = LocaleKeys.shareTab_onlyFullAccessCanInvite.tr();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // share page with user by email
            // 1. user with full access can invite others
            // 2. user in pro plan can invite others
            VSpace(theme.spacing.l),
            ShareWithUserWidget(
              controller: controller,
              disabled: !isFullAccess,
              tooltip: tooltip,
              onInvite: (emails) => _onSharePageWithUser(
                context,
                emails: emails,
                accessLevel: ShareAccessLevel.readOnly,
              ),
            ),

            if (!widget.isInProPlan && !state.hasClickedUpgradeToPro) ...[
              UpgradeToProWidget(
                onClose: () {
                  context.read<ShareTabBloc>().add(
                        ShareTabEvent.upgradeToProClicked(),
                      );
                },
                onUpgrade: widget.onUpgradeToPro,
              ),
            ],

            // shared users
            if (state.users.isNotEmpty) ...[
              VSpace(theme.spacing.l),
              PeopleWithAccessSection(
                isInPublicPage: state.sectionType == SharedSectionType.public,
                currentUserEmail: state.currentUser?.email ?? '',
                users: state.users,
                callbacks: _buildPeopleWithAccessSectionCallbacks(context),
              ),
            ],

            // general access
            if (state.sectionType == SharedSectionType.public) ...[
              VSpace(theme.spacing.m),
              GeneralAccessSection(
                group: SharedGroup(
                  id: widget.workspaceId,
                  name: widget.workspaceName,
                  icon: widget.workspaceIcon,
                ),
              ),
            ],

            // copy link
            VSpace(theme.spacing.xl),
            CopyLinkWidget(shareLink: state.shareLink),
            VSpace(theme.spacing.m),
          ],
        );
      },
    );
  }

  void _onSharePageWithUser(
    BuildContext context, {
    required List<String> emails,
    required ShareAccessLevel accessLevel,
  }) {
    context.read<ShareTabBloc>().add(
          ShareTabEvent.inviteUsers(emails: emails, accessLevel: accessLevel),
        );
  }

  PeopleWithAccessSectionCallbacks _buildPeopleWithAccessSectionCallbacks(
    BuildContext context,
  ) {
    return PeopleWithAccessSectionCallbacks(
      onSelectAccessLevel: (user, accessLevel) {
        context.read<ShareTabBloc>().add(
              ShareTabEvent.updateUserAccessLevel(
                email: user.email,
                accessLevel: accessLevel,
              ),
            );
      },
      onTurnIntoMember: (user) {
        context.read<ShareTabBloc>().add(
              ShareTabEvent.turnIntoMember(
                email: user.email,
                name: user.name,
              ),
            );
      },
      onRemoveAccess: (user) {
        // show a dialog to confirm the action when removing self access
        final theme = AppFlowyTheme.of(context);
        final shareTabBloc = context.read<ShareTabBloc>();
        final removingSelf =
            user.email == shareTabBloc.state.currentUser?.email;
        if (removingSelf) {
          showConfirmDialog(
            context: context,
            title: LocaleKeys.shareTab_removeYourOwnAccess.tr(),
            titleStyle: theme.textStyle.body.standard(
              color: theme.textColorScheme.primary,
            ),
            description: '',
            style: ConfirmPopupStyle.cancelAndOk,
            confirmLabel: LocaleKeys.button_remove.tr(),
            onConfirm: (_) {
              shareTabBloc.add(
                ShareTabEvent.removeUsers(emails: [user.email]),
              );
            },
          );
        } else {
          shareTabBloc.add(
            ShareTabEvent.removeUsers(emails: [user.email]),
          );
        }
      },
    );
  }

  Future<void> _onListenShareWithUserState(
    BuildContext context,
    ShareTabState state,
  ) async {
    final theme = AppFlowyTheme.of(context);

    final shareResult = state.shareResult;
    if (shareResult != null) {
      shareResult.fold((success) {
        // clear the controller to avoid showing the previous emails
        controller.clear();

        showToastNotification(
          message: LocaleKeys.shareTab_invitationSent.tr(),
        );
      }, (error) {
        String message;
        if (error.code == ErrorCode.FreePlanGuestLimitExceeded) {
          widget.onUpgradeToPro();
          return;
        }
        switch (error.code) {
          case ErrorCode.InvalidGuest:
            message = LocaleKeys.shareTab_emailAlreadyInList.tr();
            break;
          case ErrorCode.PaidPlanGuestLimitExceeded:
            message = LocaleKeys.shareTab_maxGuestsReached.tr();
            break;
          default:
            message = error.msg;
        }
        showToastNotification(
          message: message,
          type: ToastificationType.error,
        );
      });
    }

    final updateAccessLevelResult = state.updateAccessLevelResult;
    if (updateAccessLevelResult != null) {
      updateAccessLevelResult.fold((success) {
        showToastNotification(
          message: LocaleKeys.shareTab_updatedAccessLevelSuccessfully.tr(),
        );
      }, (error) {
        showToastNotification(
          message: error.msg,
          type: ToastificationType.error,
        );
      });
    }

    final turnIntoMemberResult = state.turnIntoMemberResult;
    if (turnIntoMemberResult != null) {
      final result = turnIntoMemberResult.result;
      result.fold((success) {
        showToastNotification(
          message: LocaleKeys.shareTab_turnedIntoMemberSuccessfully.tr(),
        );
      }, (error) {
        final name = turnIntoMemberResult.name;

        if (error.code == ErrorCode.NotEnoughPermissions) {
          // ask the owner to upgrade the user
          showConfirmDialog(
            context: context,
            title: 'Send the request to workspace owner',
            description:
                'Only the workspace owner can do this. Send them a request to upgrade $name to a member.',
            style: ConfirmPopupStyle.cancelAndOk,
            confirmLabel: 'Send',
            confirmButtonColor: theme.fillColorScheme.themeThick,
            onConfirm: (_) {
              // todo: implement it when backend support email notification
              showToastNotification(
                message: 'Request sent to the workspace owner',
              );
            },
          );
        } else {
          showToastNotification(
            message: error.msg,
            type: ToastificationType.error,
          );
        }
      });
    }

    final copyLinkResult = state.copyLinkResult;
    if (copyLinkResult != null) {
      await copyLinkResult.result.fold((success) async {
        final link = copyLinkResult.link;
        void onConfirm() {
          getIt<ClipboardService>().setData(
            ClipboardServiceData(
              plainText: link,
            ),
          );

          showToastNotification(
            message: LocaleKeys.shareTab_copiedLinkToClipboard.tr(),
          );
        }

        final toastType = copyLinkResult.toastType;
        if (toastType == CopyLinkToastType.none) {
          onConfirm();
          return;
        }

        String description = '';
        if (toastType == CopyLinkToastType.publicPage) {
          description = LocaleKeys.shareTab_copyLinkPublicPageTitle.tr();
        } else if (toastType == CopyLinkToastType.privateOrSharedPage) {
          description =
              LocaleKeys.shareTab_copyLinkPrivateOrSharePageTitle.tr();
        }

        widget.showDialogCallback(true);

        await showCancelAndConfirmDialog(
          context: context,
          title: LocaleKeys.shareTab_copyLink.tr(),
          confirmLabel: LocaleKeys.button_copyLink.tr(),
          description: description,
          onConfirm: (_) {
            onConfirm();
          },
        );

        widget.showDialogCallback(false);
      }, (error) {
        showToastNotification(
          message: error.msg,
          type: ToastificationType.error,
        );
      });
    }
  }
}
