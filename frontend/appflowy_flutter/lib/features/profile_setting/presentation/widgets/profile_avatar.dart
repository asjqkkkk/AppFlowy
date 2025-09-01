import 'package:appflowy/features/profile_setting/logic/profile_setting_bloc.dart';
import 'package:appflowy/features/profile_setting/logic/profile_setting_event.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/shared/custom_image_cache_manager.dart';
import 'package:appflowy/shared/icon_emoji_picker/flowy_icon_emoji_picker.dart';
import 'package:appflowy/shared/icon_emoji_picker/tab.dart';
import 'package:appflowy_backend/protobuf/flowy-user/workspace.pbenum.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({super.key});

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  bool hovering = false;
  final popoverController = AFPopoverController();

  @override
  void dispose() {
    popoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ProfileSettingBloc>(),
        profile = bloc.state.profile,
        isLocal = bloc.userProfile.workspaceType == WorkspaceTypePB.Vault;
    final isNetworkImageAvatar =
        profile.avatarUrl.isNotEmpty && profile.avatarUrl.startsWith('http');
    PickerTabType initialType = PickerTabType.emoji;
    if (!isLocal && isNetworkImageAvatar) {
      initialType = PickerTabType.custom;
    }

    return AFPopover(
      controller: popoverController,
      child: buildUploadButton(),
      popover: (context) {
        return ConstrainedBox(
          constraints: BoxConstraints.loose(const Size(400, 400)),
          child: FlowyIconEmojiPicker(
            initialType: initialType,
            tabs: [
              if (!isLocal) PickerTabType.custom,
              PickerTabType.emoji,
            ],
            showRemoveButton: profile.avatarUrl.isNotEmpty,
            documentId: bloc.workspaceId,
            onSelectedEmoji: (r) {
              bloc.add(ProfileSettingEvent.updateAvatar(r.emoji));
              if (!r.keepOpen) popoverController.hide();
            },
          ),
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
                email: profile.email,
                radius: spacing.m,
                size: AFAvatarSize.xxl,
                name: profile.name,
                url: profile.avatarUrl,
                cacheManager: CustomAvatarCacheManager(),
                progressIndicatorBuilder: (context, url, progress) =>
                    Center(child: CircularProgressIndicator.adaptive()),
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
