import 'package:appflowy/core/helpers/url_launcher.dart';
import 'package:appflowy/features/workspace/logic/personal_subscription_bloc.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/shared/appflowy_hosted.dart';
import 'package:appflowy/shared/icon_emoji_picker/flowy_icon_emoji_picker.dart';
import 'package:appflowy/util/debounce.dart';
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
  String workspaceIcon,
  WorkspaceType workspaceType,
);

enum WorkspaceType {
  cloud,
  vault,
}

Future<void> showCreateWorkspaceDialog(BuildContext context) {
  final bloc = context.read<UserWorkspaceBloc>();
  final state = bloc.state;
  final userName = state.userProfile.name;

  return showDialog<void>(
    context: context,
    builder: (_) {
      return CreateWorkspaceDialog(
        userName: userName,
        onSubscribeVaultWorkspace: () {
          // open checkout link
          bloc.add(
            UserWorkspaceEvent.subscribePersonalPlan(
              plan: PersonalPlanPB.VaultWorkspace,
            ),
          );
        },
        createWorkspaceCallback: (workspaceName, workspaceIcon, workspaceType) {
          bloc.add(
            UserWorkspaceEvent.createWorkspace(
              name: workspaceName,
              icon: workspaceIcon,
              workspaceType: workspaceType == WorkspaceType.cloud
                  ? WorkspaceTypePB.ServerW
                  : WorkspaceTypePB.LocalW,
            ),
          );
        },
      );
    },
  );
}

class CreateWorkspaceDialog extends StatefulWidget {
  const CreateWorkspaceDialog({
    super.key,
    required this.userName,
    required this.createWorkspaceCallback,
    required this.onSubscribeVaultWorkspace,
  });

  final String userName;
  final CreateWorkspaceCallback? createWorkspaceCallback;
  final VoidCallback onSubscribeVaultWorkspace;

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
        setState(() => isEmpty = textController.text.trim().isEmpty);
      });
    isEmpty = textController.text.trim().isEmpty;

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
              child: BlocProvider(
                create: (context) => PersonalSubscriptionBloc()
                  ..add(PersonalSubscriptionEvent.initialize()),
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
                      onTapWhenDisabled: widget.onSubscribeVaultWorkspace,
                      onChanged: (newType) {
                        setState(() => workspaceType = newType);
                      },
                    ),
                  ],
                ),
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
    Navigator.of(context).pop();
  }
}

class _IconAndDescription extends StatefulWidget {
  const _IconAndDescription({
    required this.textController,
    required this.icon,
    required this.onChangeIcon,
  });

  final TextEditingController textController;
  final String icon;
  final void Function(String newIcon) onChangeIcon;

  @override
  State<_IconAndDescription> createState() => _IconAndDescriptionState();
}

class _IconAndDescriptionState extends State<_IconAndDescription> {
  String name = '';
  final debounce = Debounce(duration: const Duration(milliseconds: 500));

  @override
  void initState() {
    super.initState();
    widget.textController.addListener(debounceUpdate);
    name = widget.textController.text;
  }

  @override
  void dispose() {
    widget.textController.removeListener(debounceUpdate);
    debounce.dispose();
    super.dispose();
  }

  void debounceUpdate() {
    debounce.call(() {
      setState(() {
        name = widget.textController.text;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Row(
      children: [
        WorkspaceIcon(
          workspaceName: name,
          workspaceIcon: widget.icon,
          iconSize: 48,
          fontSize: 18,
          emojiSize: 24,
          borderRadius: theme.borderRadius.l,
          figmaLineHeight: 26,
          isEditable: true,
          onSelected: (newIcon) {
            if (newIcon.type == FlowyIconType.emoji || newIcon.isEmpty) {
              widget.onChangeIcon(newIcon.emoji);
            }
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
    required this.onChanged,
    required this.onTapWhenDisabled,
  });

  final WorkspaceType workspaceType;
  final void Function(WorkspaceType) onChanged;
  final VoidCallback onTapWhenDisabled;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                LocaleKeys.workspace_workspaceType.tr(),
                style: theme.textStyle.caption.enhanced(
                  color: theme.textColorScheme.secondary,
                ),
              ),
            ),
            HSpace(
              theme.spacing.xs,
            ),
            FlowyTooltip(
              message: LocaleKeys.workspace_learnMore.tr(),
              child: AFGhostButton.normal(
                onTap: () => afLaunchUrlString(
                  "https://appflowy.com/guide/vault-workspace",
                ),
                padding: EdgeInsets.zero,
                builder: (context, isHovering, disabled) => FlowySvg(
                  FlowySvgs.ai_explain_m,
                  size: Size.square(20),
                  color: theme.iconColorScheme.secondary,
                ),
              ),
            ),
          ],
        ),
        VSpace(
          theme.spacing.xs,
        ),
        FutureBuilder<bool>(
          future: isOfficialHosted(),
          builder: (context, snapshot) {
            return Row(
              children: [
                Expanded(
                  child: _WorkspaceTypeCard(
                    workspaceType: WorkspaceType.cloud,
                    isLoading: false,
                    isDisabled: false,
                    isSelected: workspaceType == WorkspaceType.cloud,
                    onTap: () => onChanged(WorkspaceType.cloud),
                  ),
                ),
                HSpace(
                  theme.spacing.m,
                ),
                if (snapshot.data == true) ...[
                  Expanded(
                    child: BlocBuilder<PersonalSubscriptionBloc,
                        PersonalSubscriptionState>(
                      builder: (context, state) {
                        final isVaultLoading =
                            state is PersonalSubscriptionStateLoading;
                        final isVaultDisabled =
                            state is PersonalSubscriptionStateLoaded &&
                                !state.hasVaultSubscription;

                        return _WorkspaceTypeCard(
                          workspaceType: WorkspaceType.vault,
                          isDisabled: false,
                          isLoading: isVaultLoading,
                          isSelected: workspaceType == WorkspaceType.vault,
                          onTap: () {
                            if (isVaultDisabled) {
                              onTapWhenDisabled();
                            } else {
                              onChanged(WorkspaceType.vault);
                            }
                          },
                          tooltipMessage: !isVaultLoading && isVaultDisabled
                              ? LocaleKeys
                                  .workspace_clickToSubscribeVaultWorkspace
                                  .tr()
                              : null,
                        );
                      },
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _WorkspaceTypeCard extends StatelessWidget {
  const _WorkspaceTypeCard({
    required this.workspaceType,
    required this.isSelected,
    required this.isLoading,
    required this.isDisabled,
    required this.onTap,
    this.tooltipMessage,
  });

  final WorkspaceType workspaceType;
  final bool isSelected;
  final bool isLoading;
  final bool isDisabled;
  final VoidCallback onTap;
  final String? tooltipMessage;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return FlowyTooltip(
      verticalOffset: 30.0,
      message: tooltipMessage,
      preferBelow: false,
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
                color: isSelected
                    ? theme.borderColorScheme.themeThick
                    : theme.borderColorScheme.primary,
              ),
            ),
            child: Row(
              children: [
                if (isLoading)
                  SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                else
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
