import 'package:appflowy/features/profile_setting/logic/profile_setting_bloc.dart';
import 'package:appflowy/features/profile_setting/logic/profile_setting_event.dart';
import 'package:appflowy/features/profile_setting/logic/profile_setting_state.dart';
import 'package:appflowy/features/profile_setting/presentation/widgets/profile_preview_widget.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/show_mobile_bottom_sheet.dart';
import 'package:appflowy/shared/icon_emoji_picker/flowy_icon_emoji_picker.dart';
import 'package:appflowy/shared/icon_emoji_picker/tab.dart';
import 'package:appflowy_backend/protobuf/flowy-user/user_profile.pb.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'mobile_profile_banner.dart';

class MobileAccountProfile extends StatelessWidget {
  const MobileAccountProfile({super.key, required this.userProfile});

  final UserProfilePB userProfile;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context),
        spacing = theme.spacing,
        size = MediaQuery.of(context).size;

    return BlocBuilder<ProfileSettingBloc, ProfileSettingState>(
      builder: (context, state) {
        final bloc = context.read<ProfileSettingBloc>(),
            profile = state.profile,
            hasDescription = profile.aboutMe.isNotEmpty;
        return Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding:
                      EdgeInsets.fromLTRB(spacing.xl, spacing.l, spacing.xl, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MobileProfileBanner(
                        size: Size(size.width, 92),
                        banner: profile.banner,
                      ),
                      VSpace(64),
                      Text(
                        profile.name,
                        style: theme.textStyle.heading3
                            .enhanced(color: theme.textColorScheme.primary),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        profile.email,
                        style: theme.textStyle.heading4
                            .standard(color: theme.textColorScheme.primary),
                        textAlign: TextAlign.center,
                      ),
                      if (hasDescription) ...[
                        VSpace(spacing.l),
                        context.buildDescription(textAlign: TextAlign.center),
                      ],
                    ],
                  ),
                ),
                VSpace(spacing.m),
                AFDivider(spacing: spacing.m),
              ],
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 58),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    showMobileBottomSheet(
                      context,
                      showDragHandle: true,
                      showDivider: false,
                      showHeader: true,
                      showCloseButton: true,
                      title: LocaleKeys.settings_profilePage_editAvatar.tr(),
                      backgroundColor: theme.surfaceColorScheme.layer01,
                      enableDraggableScrollable: true,
                      minChildSize: 0.6,
                      initialChildSize: 0.61,
                      scrollableWidgetBuilder: (ctx, controller) {
                        final isNetworkImageAvatar =
                            profile.avatarUrl.isNotEmpty &&
                                profile.avatarUrl.startsWith('http');
                        PickerTabType initialType = PickerTabType.emoji;
                        if (isNetworkImageAvatar) {
                          initialType = PickerTabType.custom;
                        }

                        return Expanded(
                          child: FlowyIconEmojiPicker(
                            initialType: initialType,
                            documentId: bloc.userProfile.id.toString(),
                            tabs: [
                              PickerTabType.custom,
                              PickerTabType.emoji,
                            ],
                            onSelectedEmoji: (r) {
                              bloc.add(
                                ProfileSettingEvent.updateAvatar(r.emoji),
                              );
                              if (!r.keepOpen) Navigator.pop(ctx);
                            },
                          ),
                        );
                      },
                      builder: (_) => const SizedBox.shrink(),
                    );
                  },
                  child: context.buildAvatar(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
