import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/shared/feature_flags.dart';
import 'package:appflowy/shared/icon_emoji_picker/flowy_icon_emoji_picker.dart';
import 'package:appflowy/workspace/application/user/prelude.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '_sidebar_workspace_icon.dart';

typedef CreateWorkspaceCallback = void Function(
  String workspaceName,
  String icon,
  WorkspaceType workspaceType,
);

enum WorkspaceType {
  cloud,
  vault,
}

Future<void> showCreateWorkspaceDialog(
  BuildContext context, {
  required CreateWorkspaceCallback? createWorkspaceCallback,
}) {
  final state = context.read<UserWorkspaceBloc>().state;
  final userName = state.userProfile.name;

  final subscriptionInfo = state.workspaceSubscriptionInfo;
  final isProPlan = subscriptionInfo != null &&
      subscriptionInfo.plan.value >= WorkspacePlanPB.ProPlan.value;
  final allowCreateVault = isProPlan || FeatureFlag.createVaultWorkspace.isOn;

  return showDialog<void>(
    context: context,
    builder: (_) {
      return CreateWorkspaceDialog(
        userName: userName,
        allowCreateVault: allowCreateVault,
        createWorkspaceCallback: createWorkspaceCallback,
      );
    },
  );
}

class CreateWorkspaceDialog extends StatefulWidget {
  const CreateWorkspaceDialog({
    super.key,
    required this.userName,
    required this.allowCreateVault,
    required this.createWorkspaceCallback,
  });

  final String userName;
  final bool allowCreateVault;
  final CreateWorkspaceCallback? createWorkspaceCallback;

  @override
  State<CreateWorkspaceDialog> createState() => _CreateWorkspaceDialogState();
}

class _CreateWorkspaceDialogState extends State<CreateWorkspaceDialog> {
  late final TextEditingController textController;
  final focusNode = FocusNode();

  String icon = '';
  bool isEmpty = false;
  WorkspaceType workspaceType = WorkspaceType.cloud;

  @override
  void initState() {
    super.initState();

    final text = widget.userName.isNotEmpty
        ? LocaleKeys.workspace_workspaceNameWithUserName
            .tr(args: [widget.userName])
        : LocaleKeys.workspace_workspaceNameFallback.tr();

    textController = TextEditingController()
      ..value = TextEditingValue(
        text: text,
        selection: TextSelection(baseOffset: 0, extentOffset: text.length),
      )
      ..addListener(() {
        setState(() => isEmpty = textController.text.isEmpty);
      });
    isEmpty = textController.text.isEmpty;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    textController.dispose();
    focusNode.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return AFModal(
      constraints: const BoxConstraints(
        maxWidth: 500,
        maxHeight: 400,
      ),
      child: Column(
        children: [
          AFModalHeader(
            leading: Text(
              LocaleKeys.workspace_createANewWorkspace.tr(),
              style: theme.textStyle.heading4.prominent(
                color: theme.textColorScheme.primary,
              ),
            ),
            trailing: [
              AFGhostButton.normal(
                onTap: () => Navigator.of(context).pop(),
                padding: EdgeInsets.all(theme.spacing.xs),
                builder: (context, isHovering, isDisabled) {
                  return Center(
                    child: FlowySvg(
                      FlowySvgs.toast_close_s,
                      size: Size.square(20),
                    ),
                  );
                },
              ),
            ],
          ),
          Expanded(
            child: AFModalBody(
              child: Column(
                children: [
                  _IconAndDescription(
                    textController: textController,
                    icon: icon,
                    onChangeIcon: (newIcon) {
                      setState(() => icon = newIcon);
                    },
                  ),
                  VSpace(
                    theme.spacing.xxl,
                  ),
                  _WorkspaceName(
                    textController: textController,
                    focusNode: focusNode,
                  ),
                  VSpace(
                    theme.spacing.xl,
                  ),
                  _WorkspaceType(
                    workspaceType: workspaceType,
                    allowCreateVault: widget.allowCreateVault,
                    onChanged: (newType) {
                      setState(() => workspaceType = newType);
                    },
                  ),
                ],
              ),
            ),
          ),
          AFModalFooter(
            trailing: [
              AFOutlinedTextButton.normal(
                onTap: () => Navigator.of(context).pop(),
                text: LocaleKeys.button_cancel.tr(),
              ),
              AFFilledTextButton.primary(
                disabled: isEmpty,
                text: LocaleKeys.workspace_create.tr(),
                onTap: handleCreateWorkspace,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void handleCreateWorkspace() {
    final name = textController.text;
    if (name.isEmpty) {
      return;
    }

    widget.createWorkspaceCallback?.call(name, icon, workspaceType);
  }
}

class _IconAndDescription extends StatelessWidget {
  const _IconAndDescription({
    required this.textController,
    required this.icon,
    required this.onChangeIcon,
  });

  final TextEditingController textController;
  final String icon;
  final void Function(String newIcon) onChangeIcon;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Row(
      children: [
        ValueListenableBuilder(
          valueListenable: textController,
          builder: (context, value, _) {
            return WorkspaceIcon(
              workspaceName: value.text,
              workspaceIcon: icon,
              iconSize: 48,
              fontSize: 18,
              emojiSize: 24,
              borderRadius: theme.borderRadius.l,
              figmaLineHeight: 26,
              isEditable: true,
              onSelected: (newIcon) {
                if (newIcon.type == FlowyIconType.emoji || newIcon.isEmpty) {
                  onChangeIcon(newIcon.emoji);
                }
              },
            );
          },
        ),
        HSpace(
          theme.spacing.xl,
        ),
        Expanded(
          child: Text(
            LocaleKeys.workspace_createWorkspaceDescription.tr(),
            style: theme.textStyle.body.standard(
              color: theme.textColorScheme.secondary,
            ),
            maxLines: 3,
          ),
        ),
      ],
    );
  }
}

class _WorkspaceName extends StatelessWidget {
  const _WorkspaceName({
    required this.textController,
    required this.focusNode,
  });

  final TextEditingController textController;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocaleKeys.workspace_workspaceName.tr(),
          style: theme.textStyle.caption.enhanced(
            color: theme.textColorScheme.secondary,
          ),
        ),
        VSpace(
          theme.spacing.xs,
        ),
        AFTextField(
          controller: textController,
          focusNode: focusNode,
          size: AFTextFieldSize.m,
          autoFocus: true,
        ),
      ],
    );
  }
}

class _WorkspaceType extends StatelessWidget {
  const _WorkspaceType({
    required this.workspaceType,
    required this.allowCreateVault,
    required this.onChanged,
  });

  final WorkspaceType workspaceType;
  final bool allowCreateVault;
  final void Function(WorkspaceType) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocaleKeys.workspace_workspaceType.tr(),
          style: theme.textStyle.caption.enhanced(
            color: theme.textColorScheme.secondary,
          ),
        ),
        VSpace(
          theme.spacing.xs,
        ),
        Row(
          children: [
            Expanded(
              child: _WorkspaceTypeCard(
                workspaceType: WorkspaceType.cloud,
                isDisabled: false,
                isSelected: workspaceType == WorkspaceType.cloud,
                onTap: () => onChanged(WorkspaceType.cloud),
              ),
            ),
            HSpace(
              theme.spacing.m,
            ),
            Expanded(
              child: _WorkspaceTypeCard(
                workspaceType: WorkspaceType.vault,
                isDisabled: !allowCreateVault,
                isSelected: workspaceType == WorkspaceType.vault,
                onTap: () => onChanged(WorkspaceType.vault),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WorkspaceTypeCard extends StatelessWidget {
  const _WorkspaceTypeCard({
    required this.workspaceType,
    required this.isSelected,
    required this.isDisabled,
    required this.onTap,
  });

  final WorkspaceType workspaceType;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return FlowyTooltip(
      verticalOffset: 30.0,
      preferBelow: false,
      message: isDisabled
          ? LocaleKeys.workspace_createVaultWorkspaceDisabled.tr()
          : null,
      child: GestureDetector(
        onTap: () {
          if (!isDisabled) {
            onTap();
          }
        },
        child: MouseRegion(
          cursor: isDisabled ? MouseCursor.defer : SystemMouseCursors.click,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.xl,
              vertical: theme.spacing.l,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(theme.borderRadius.m),
              border: Border.all(
                width: isSelected ? 2.0 : 1.0,
                color: isSelected
                    ? theme.borderColorScheme.themeThick
                    : theme.borderColorScheme.primary,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
            ),
            child: Row(
              children: [
                FlowySvg(
                  workspaceType == WorkspaceType.cloud
                      ? FlowySvgs.cloud_m
                      : FlowySvgs.lock_m,
                  size: Size.square(20),
                  color: isDisabled
                      ? theme.iconColorScheme.tertiary
                      : theme.iconColorScheme.primary,
                ),
                HSpace(
                  theme.spacing.l,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workspaceType == WorkspaceType.cloud
                            ? LocaleKeys.workspace_cloudWorkspace.tr()
                            : LocaleKeys.workspace_vaultWorkspace.tr(),
                        style: theme.textStyle.body.enhanced(
                          color: isDisabled
                              ? theme.textColorScheme.tertiary
                              : theme.textColorScheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        workspaceType == WorkspaceType.cloud
                            ? LocaleKeys.workspace_cloudWorkspaceDescription
                                .tr()
                            : LocaleKeys.workspace_vaultWorkspaceDescription
                                .tr(),
                        style: theme.textStyle.caption.standard(
                          color: isDisabled
                              ? theme.textColorScheme.tertiary
                              : theme.textColorScheme.secondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
