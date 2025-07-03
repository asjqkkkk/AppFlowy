import 'package:appflowy/features/profile_setting/logic/profile_setting_bloc.dart';
import 'package:appflowy/features/profile_setting/logic/profile_setting_event.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/shared/icon_emoji_picker/flowy_icon_emoji_picker.dart';
import 'package:appflowy/shared/icon_emoji_picker/tab.dart';
import 'package:appflowy_backend/protobuf/flowy-user/workspace.pbenum.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({super.key});

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  bool hovering = false;
  final popoverController = PopoverController();

  @override
  void dispose() {
    popoverController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ProfileSettingBloc>(),
        isLocal = bloc.userProfile.workspaceType == WorkspaceTypePB.LocalW;

    return AppFlowyPopover(
      direction: PopoverDirection.bottomWithCenterAligned,
      controller: popoverController,
      offset: const Offset(0, 8),
      constraints: BoxConstraints.loose(const Size(400, 400)),
      margin: EdgeInsets.zero,
      child: buildUploadButton(),
      popupBuilder: (BuildContext popoverContext) {
        return FlowyIconEmojiPicker(
          initialType: isLocal ? PickerTabType.emoji : PickerTabType.custom,
          tabs: [
            if (!isLocal) PickerTabType.custom,
            PickerTabType.emoji,
          ],
          documentId: bloc.workspace?.workspaceId ?? '',
          onSelectedEmoji: (r) {
            bloc.add(ProfileSettingEvent.updateAvatar(r.emoji));
            if (!r.keepOpen) popoverController.close();
          },
        );
      },
    );
  }

  Widget buildUploadButton() {
    final theme = AppFlowyTheme.of(context),
        spacing = theme.spacing,
        bloc = context.read<ProfileSettingBloc>(),
        state = bloc.state,
        profile = state.profile;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (event) => setState(() => hovering = true),
      onExit: (event) => setState(() => hovering = false),
      child: GestureDetector(
        onTap: () {
          popoverController.show();
        },
        child: SizedBox.square(
          dimension: 80,
          child: Stack(
            children: [
              AFAvatar(
                radius: spacing.m,
                size: AFAvatarSize.xxl,
                name: profile.name,
                url: profile.avatarUrl,
              ),
              if (hovering)
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: theme.surfaceColorScheme.overlay,
                    borderRadius: BorderRadius.circular(spacing.m),
                  ),
                  child: Center(
                    child: FlowySvg(
                      FlowySvgs.profile_upload_icon_m,
                      size: Size.square(20),
                      color: theme.iconColorScheme.onFill,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
