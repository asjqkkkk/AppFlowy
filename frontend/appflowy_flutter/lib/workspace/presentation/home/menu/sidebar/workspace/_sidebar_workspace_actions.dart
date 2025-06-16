import 'package:appflowy/features/workspace/logic/workspace_bloc.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/shared/af_role_pb_extension.dart';
import 'package:appflowy/workspace/presentation/widgets/dialog_v2.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy/workspace/presentation/widgets/pop_up_action.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum WorkspaceMoreAction {
  rename,
  delete,
  leave,
  divider,
}

class WorkspaceMoreActionList extends StatefulWidget {
  const WorkspaceMoreActionList({
    super.key,
    required this.currentWorkspace,
    required this.workspace,
    required this.popoverMutex,
    required this.popoverOpenNotifier,
  });

  final UserWorkspacePB currentWorkspace;
  final UserWorkspacePB workspace;
  final PopoverMutex popoverMutex;
  final ValueNotifier<bool> popoverOpenNotifier;

  @override
  State<WorkspaceMoreActionList> createState() =>
      _WorkspaceMoreActionListState();
}

class _WorkspaceMoreActionListState extends State<WorkspaceMoreActionList> {
  @override
  Widget build(BuildContext context) {
    final myRole = widget.workspace.role;
    final actions = [];
    if (myRole.isOwner) {
      actions.add(WorkspaceMoreAction.rename);
      actions.add(WorkspaceMoreAction.divider);
      actions.add(WorkspaceMoreAction.delete);
    } else if (myRole.canLeave) {
      actions.add(WorkspaceMoreAction.leave);
    }
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }
    return PopoverActionList<_WorkspaceMoreActionWrapper>(
      direction: PopoverDirection.bottomWithLeftAligned,
      actions: actions
          .map(
            (action) => _WorkspaceMoreActionWrapper(
              action,
              widget.workspace,
              () => PopoverContainer.of(context).closeAll(),
              widget.currentWorkspace.workspaceType ==
                  widget.workspace.workspaceType,
            ),
          )
          .toList(),
      mutex: widget.popoverMutex,
      constraints: const BoxConstraints(minWidth: 220),
      animationDuration: Durations.short3,
      slideDistance: 2,
      beginScaleFactor: 1.0,
      beginOpacity: 0.8,
      onClosed: () => widget.popoverOpenNotifier.value = false,
      asBarrier: true,
      buildChild: (controller) {
        return SizedBox.square(
          dimension: 24.0,
          child: FlowyButton(
            margin: const EdgeInsets.symmetric(horizontal: 4.0),
            text: const FlowySvg(
              FlowySvgs.workspace_three_dots_s,
            ),
            onTap: () {
              if (!widget.popoverOpenNotifier.value) {
                controller.show();
                widget.popoverOpenNotifier.value = true;
              } else {
                controller.close();
                widget.popoverOpenNotifier.value = false;
              }
            },
          ),
        );
      },
      onSelected: (action, controller) {},
    );
  }
}

class _WorkspaceMoreActionWrapper extends CustomActionCell {
  _WorkspaceMoreActionWrapper(
    this.inner,
    this.workspace,
    this.closeWorkspaceMenu,
    this.isSameWorkspaceType,
  );

  final WorkspaceMoreAction inner;
  final UserWorkspacePB workspace;
  final VoidCallback closeWorkspaceMenu;
  final bool isSameWorkspaceType;

  @override
  Widget buildWithContext(
    BuildContext context,
    PopoverController controller,
    PopoverMutex? mutex,
  ) {
    if (inner == WorkspaceMoreAction.divider) {
      return const Divider();
    }

    return _buildActionButton(context, controller);
  }

  Widget _buildActionButton(
    BuildContext context,
    PopoverController controller,
  ) {
    final theme = AppFlowyTheme.of(context);
    final isDestructive = [
      WorkspaceMoreAction.delete,
      WorkspaceMoreAction.leave,
    ].contains(inner);

    return FlowyTooltip(
      message: [
                WorkspaceMoreAction.delete,
                WorkspaceMoreAction.rename,
                WorkspaceMoreAction.leave,
              ].contains(inner) &&
              !isSameWorkspaceType
          ? LocaleKeys.workspace_differentWorkspaceTypeTooltip.tr()
          : '',
      child: AFBaseButton(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.m,
          vertical: theme.spacing.s,
        ),
        onTap: () async {
          PopoverContainer.of(context).closeAll();
          closeWorkspaceMenu();

          final workspaceBloc = context.read<UserWorkspaceBloc>();
          switch (inner) {
            case WorkspaceMoreAction.divider:
              break;
            case WorkspaceMoreAction.delete:
              await showSimpleAFDialog(
                context: context,
                title: LocaleKeys.workspace_deleteWorkspace.tr(),
                content: LocaleKeys.workspace_deleteWorkspaceHintText.tr(),
                isDestructive: true,
                primaryAction: (
                  LocaleKeys.button_delete.tr(),
                  (_) {
                    workspaceBloc.add(
                        UserWorkspaceEvent.deleteWorkspace(
                          workspaceId: workspace.workspaceId,
                        ),
                      );
                  },
                ),
                secondaryAction: (
                  LocaleKeys.button_cancel.tr(),
                  (_) {},
                ),
              );
            case WorkspaceMoreAction.rename:
              await showAFTextFieldDialog(
                context: context,
                title: LocaleKeys.workspace_renameWorkspace.tr(),
                initialValue: workspace.name,
                hintText: '',
                onConfirm: (name) async {
                  workspaceBloc.add(
                    UserWorkspaceEvent.renameWorkspace(
                      workspaceId: workspace.workspaceId,
                      name: name,
                    ),
                  );
                },
              );
            case WorkspaceMoreAction.leave:
              await showConfirmDialog(
                context: context,
                title: LocaleKeys.workspace_leaveCurrentWorkspace.tr(),
                description:
                    LocaleKeys.workspace_leaveCurrentWorkspacePrompt.tr(),
                confirmLabel: LocaleKeys.button_yes.tr(),
                onConfirm: (_) {
                  workspaceBloc.add(
                    UserWorkspaceEvent.leaveWorkspace(
                      workspaceId: workspace.workspaceId,
                    ),
                  );
                },
              );
          }
        },
        disabled: !isSameWorkspaceType,
        borderRadius: theme.borderRadius.m,
        borderColor: (context, isHovering, disabled, isFocused) {
          return Colors.transparent;
        },
        backgroundColor: (context, isHovering, disabled) {
          final theme = AppFlowyTheme.of(context);
          if (disabled) {
            return theme.fillColorScheme.content;
          }
          if (isHovering) {
            return theme.fillColorScheme.contentHover;
          }
          return theme.fillColorScheme.content;
        },
        builder: (context, isHovering, disabled) {
          return Row(
            spacing: theme.spacing.m,
            children: [
              buildLeftIcon(context, !isSameWorkspaceType, isDestructive),
              Expanded(
                child: Text(
                  name,
                  style: theme.textStyle.body.standard(
                    color: !isSameWorkspaceType
                        ? theme.textColorScheme.tertiary
                        : isDestructive
                            ? theme.textColorScheme.error
                            : theme.textColorScheme.primary,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String get name {
    switch (inner) {
      case WorkspaceMoreAction.delete:
        return LocaleKeys.button_delete.tr();
      case WorkspaceMoreAction.rename:
        return LocaleKeys.button_rename.tr();
      case WorkspaceMoreAction.leave:
        return LocaleKeys.workspace_leaveCurrentWorkspace.tr();
      case WorkspaceMoreAction.divider:
        return '';
    }
  }

  Widget buildLeftIcon(
    BuildContext context,
    bool isDisabled,
    bool isDestructive,
  ) {
    final theme = AppFlowyTheme.of(context);
    final color = isDisabled
        ? theme.iconColorScheme.tertiary
        : isDestructive
            ? theme.iconColorScheme.errorThick
            : theme.iconColorScheme.primary;
    switch (inner) {
      case WorkspaceMoreAction.delete:
        return FlowySvg(
          FlowySvgs.trash_s,
          color: color,
        );
      case WorkspaceMoreAction.rename:
        return FlowySvg(
          FlowySvgs.view_item_rename_s,
          color: color,
        );
      case WorkspaceMoreAction.leave:
        return FlowySvg(
          FlowySvgs.logout_s,
          color: color,
        );
      case WorkspaceMoreAction.divider:
        return const SizedBox.shrink();
    }
  }
}
