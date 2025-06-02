import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/util/theme_extension.dart';
import 'package:appflowy/workspace/application/user/user_workspace_bloc.dart';
import 'package:appflowy/workspace/presentation/home/menu/sidebar/space/_extension.dart';
import 'package:appflowy/workspace/presentation/home/menu/sidebar/space/shared_widget.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CreateWorkspacePopup extends StatefulWidget {
  const CreateWorkspacePopup({super.key});

  @override
  State<CreateWorkspacePopup> createState() => _CreateWorkspacePopupState();
}

class _CreateWorkspacePopupState extends State<CreateWorkspacePopup> {
  String workspaceName = LocaleKeys.workspace_defaultName.tr();
  WorkspaceTypePB workspaceType = WorkspaceTypePB.ServerW;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
      width: 524,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FlowyText(
            LocaleKeys.workspace_create.tr(),
            fontSize: 18.0,
            figmaLineHeight: 24.0,
          ),
          const VSpace(12.0),
          _WorkspaceNameTextField(
            onChanged: (value) => workspaceName = value,
            onSubmitted: (value) {
              _createWorkspace();
            },
          ),
          const VSpace(20.0),
          WorkspaceTypeSwitch(
            workspaceType: workspaceType,
            onTypeChanged: (value) => workspaceType = value,
          ),
          const VSpace(20.0),
          SpaceCancelOrConfirmButton(
            confirmButtonName: LocaleKeys.button_create.tr(),
            onCancel: () => Navigator.of(context).pop(),
            onConfirm: () => _createWorkspace(),
          ),
        ],
      ),
    );
  }

  void _createWorkspace() {
    context.read<UserWorkspaceBloc>().add(
          UserWorkspaceEvent.createWorkspace(
            name: workspaceName,
            workspaceType: workspaceType,
          ),
        );

    Navigator.of(context).pop();
  }
}

class _WorkspaceNameTextField extends StatelessWidget {
  const _WorkspaceNameTextField({
    required this.onChanged,
    required this.onSubmitted,
  });

  final void Function(String name) onChanged;
  final void Function(String name) onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: FlowyTextField(
            hintText: LocaleKeys.workspace_defaultName.tr(),
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            enableBorderColor: context.enableBorderColor,
          ),
        ),
      ],
    );
  }
}

class WorkspaceTypeSwitch extends StatefulWidget {
  const WorkspaceTypeSwitch({
    super.key,
    required this.onTypeChanged,
    required this.workspaceType,
    this.showArrow = false,
  });

  final WorkspaceTypePB? workspaceType;
  final void Function(WorkspaceTypePB type) onTypeChanged;
  final bool showArrow;

  @override
  State<WorkspaceTypeSwitch> createState() => _WorkspaceTypeSwitchState();
}

class _WorkspaceTypeSwitchState extends State<WorkspaceTypeSwitch> {
  late WorkspaceTypePB workspaceType =
      widget.workspaceType ?? WorkspaceTypePB.ServerW;
  final popoverController = PopoverController();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FlowyText.regular(
          LocaleKeys.workspace_workspaceType.tr(),
          fontSize: 14.0,
          color: Theme.of(context).hintColor,
          figmaLineHeight: 18.0,
        ),
        const VSpace(6.0),
        AppFlowyPopover(
          controller: popoverController,
          direction: PopoverDirection.bottomWithCenterAligned,
          constraints: const BoxConstraints(maxWidth: 500),
          offset: const Offset(0, 4),
          margin: EdgeInsets.zero,
          popupBuilder: (_) => _buildWorkspaceTypeButtons(),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: RoundedRectangleBorder(
                side: BorderSide(color: context.enableBorderColor),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: WorkspaceTypeButton(
              showArrow: true,
              workspaceType: workspaceType,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkspaceTypeButtons() {
    return SizedBox(
      width: 452,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          WorkspaceTypeButton(
            workspaceType: WorkspaceTypePB.ServerW,
            onTap: () => _onWorkspaceTypeChanged(WorkspaceTypePB.ServerW),
          ),
          WorkspaceTypeButton(
            workspaceType: WorkspaceTypePB.LocalW,
            onTap: () => _onWorkspaceTypeChanged(WorkspaceTypePB.LocalW),
          ),
        ],
      ),
    );
  }

  void _onWorkspaceTypeChanged(WorkspaceTypePB newWorkspaceType) {
    widget.onTypeChanged(newWorkspaceType);

    setState(() {
      workspaceType = newWorkspaceType;
    });

    popoverController.close();
  }
}

class WorkspaceTypeButton extends StatelessWidget {
  const WorkspaceTypeButton({
    super.key,
    required this.workspaceType,
    this.onTap,
    this.showArrow = false,
  });

  final WorkspaceTypePB workspaceType;
  final VoidCallback? onTap;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    final (title, desc, icon) = switch (workspaceType) {
      WorkspaceTypePB.ServerW => (
          LocaleKeys.workspace_publicWorkspace.tr(),
          LocaleKeys.workspace_publicWorkspaceDescription.tr(),
          FlowySvgs.space_permission_public_s
        ),
      WorkspaceTypePB.LocalW => (
          LocaleKeys.workspace_vaultWorkspace.tr(),
          LocaleKeys.workspace_vaultWorkspaceDescription.tr(),
          FlowySvgs.space_permission_private_s
        ),
      _ => throw UnimplementedError(),
    };

    return FlowyButton(
      margin: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      radius: showArrow ? BorderRadius.circular(10) : BorderRadius.zero,
      iconPadding: 16.0,
      leftIcon: FlowySvg(icon),
      leftIconSize: const Size.square(20),
      rightIcon: showArrow
          ? const FlowySvg(FlowySvgs.space_permission_dropdown_s)
          : null,
      borderColor: Theme.of(context).isLightMode
          ? const Color(0x1E171717)
          : const Color(0xFF3A3F49),
      text: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FlowyText.regular(title),
          const VSpace(4.0),
          FlowyText.regular(
            desc,
            fontSize: 12.0,
            color: Theme.of(context).hintColor,
            maxLines: 3,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
