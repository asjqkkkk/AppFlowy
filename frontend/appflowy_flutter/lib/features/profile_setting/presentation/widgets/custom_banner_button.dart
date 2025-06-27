import 'package:appflowy/features/profile_setting/data/banner.dart';
import 'package:appflowy/features/profile_setting/logic/profile_setting_bloc.dart';
import 'package:appflowy/features/profile_setting/logic/profile_setting_event.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/shared/icon_emoji_picker/flowy_icon_emoji_picker.dart';
import 'package:appflowy/shared/icon_emoji_picker/tab.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'image_banner_widget.dart';

class CustomBannerButton extends StatefulWidget {
  const CustomBannerButton({
    super.key,
    required this.banner,
  });

  final NetworkImageBanner banner;

  @override
  State<CustomBannerButton> createState() => _CustomBannerButtonState();
}

class _CustomBannerButtonState extends State<CustomBannerButton> {
  bool hovering = false;
  final popoverController = PopoverController();

  NetworkImageBanner get banner => widget.banner;
  @override
  void dispose() {
    popoverController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ProfileSettingBloc>(),
        selected = bloc.state.selectedBanner == banner;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (e) => setState(() {
        hovering = true;
      }),
      onExit: (e) => setState(() {
        hovering = false;
      }),
      child: GestureDetector(
        onTap: () {
          bloc.add(ProfileSettingEvent.selectBanner(banner));
        },
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            IgnorePointer(
              child: AppFlowyPopover(
                direction: PopoverDirection.bottomWithCenterAligned,
                controller: popoverController,
                offset: const Offset(0, 8),
                constraints: BoxConstraints.loose(const Size(400, 400)),
                margin: EdgeInsets.zero,
                child: banner.toWidget(context: context, selected: selected),
                popupBuilder: (BuildContext popoverContext) {
                  return FlowyIconEmojiPicker(
                    initialType: PickerTabType.custom,
                    tabs: const [PickerTabType.custom],
                    showRemoveButton: false,
                    documentId: bloc.workspace?.workspaceId ?? '',
                    onSelectedEmoji: (r) {
                      bloc.add(
                        ProfileSettingEvent.uploadBanner(
                          NetworkImageBanner(url: r.emoji),
                        ),
                      );
                      if (!r.keepOpen) popoverController.close();
                    },
                  );
                },
              ),
            ),
            if (hovering) Positioned(right: 8, top: 8, child: buildEditIcon()),
          ],
        ),
      ),
    );
  }

  Widget buildEditIcon() {
    final theme = AppFlowyTheme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          popoverController.show();
        },
        child: Container(
          padding: EdgeInsets.all(theme.spacing.xs),
          decoration: BoxDecoration(
            color: theme.surfaceColorScheme.layer01,
            borderRadius: BorderRadius.circular(theme.spacing.s),
          ),
          child: FlowySvg(
            FlowySvgs.banner_edit_icon_s,
            size: Size.square(16),
            color: theme.iconColorScheme.secondary,
          ),
        ),
      ),
    );
  }
}
