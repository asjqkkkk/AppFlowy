import 'package:appflowy/features/profile_setting/data/banner.dart';
import 'package:appflowy/features/profile_setting/logic/profile_setting_bloc.dart';
import 'package:appflowy/features/profile_setting/logic/profile_setting_event.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/shared/icon_emoji_picker/flowy_icon_emoji_picker.dart';
import 'package:appflowy/shared/icon_emoji_picker/tab.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'custom_banner_button.dart';
import 'banner_widget.dart';
import 'profile_buttons.dart';

class BannerImages extends StatelessWidget {
  const BannerImages({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context),
        spacing = theme.spacing,
        bloc = context.read<ProfileSettingBloc>(),
        state = bloc.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          LocaleKeys.settings_profilePage_bannerImage.tr(),
          style: theme.textStyle.body
              .enhanced(color: theme.textColorScheme.primary),
        ),
        VSpace(spacing.l),
        Text(
          LocaleKeys.settings_profilePage_customImage.tr(),
          style: theme.textStyle.caption
              .prominent(color: theme.textColorScheme.tertiary),
        ),
        VSpace(spacing.xs),
        _UploadButton(),
        VSpace(spacing.xxl),
        Text(
          LocaleKeys.settings_profilePage_wallpapers.tr(),
          style: theme.textStyle.caption
              .prominent(color: theme.textColorScheme.tertiary),
        ),
        VSpace(spacing.xs),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 660,
          ),
          child: LayoutBuilder(
            builder: (context, constrains) {
              final width = constrains.maxWidth;
              final itemWidth = (width - spacing.s * 3) / 4;
              return GridView.count(
                crossAxisCount: 4,
                mainAxisSpacing: spacing.s,
                crossAxisSpacing: spacing.s,
                childAspectRatio: itemWidth / 52,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: List.generate(defaultBanners.length, (index) {
                  final banner = defaultBanners[index];
                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        bloc.add(ProfileSettingSelectBannerEvent(banner));
                      },
                      child: banner.toWidget(
                        context: context,
                        selected: banner == state.selectedBanner,
                        isDefault: index == 0,
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UploadButton extends StatefulWidget {
  const _UploadButton();

  @override
  State<_UploadButton> createState() => _UploadButtonState();
}

class _UploadButtonState extends State<_UploadButton> {
  final popoverController = PopoverController();

  @override
  void dispose() {
    popoverController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildButtonWithPlaceHolder();
  }

  Widget buildPopover() {
    final bloc = context.read<ProfileSettingBloc>(),
        state = bloc.state,
        customBanner = state.profile.customBanner;
    if (customBanner != null) {
      return CustomBannerButton(banner: customBanner);
    }
    return AppFlowyPopover(
      direction: PopoverDirection.bottomWithCenterAligned,
      controller: popoverController,
      offset: const Offset(0, 8),
      constraints: BoxConstraints.loose(const Size(400, 400)),
      margin: EdgeInsets.zero,
      child: BannerUploadButton(onTap: () => popoverController.show()),
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
    );
  }

  Widget buildUploadButton() {
    final theme = AppFlowyTheme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          popoverController.show();
        },
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            border: Border.all(color: theme.borderColorScheme.primary),
            borderRadius: BorderRadius.circular(theme.spacing.m),
          ),
          child: Center(
            child: FlowySvg(
              FlowySvgs.profile_add_icon_m,
              size: Size.square(20),
              color: theme.iconColorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildButtonWithPlaceHolder() {
    final theme = AppFlowyTheme.of(context), spacing = theme.spacing;
    final widgets = [
      buildPopover(),
      SizedBox.shrink(),
      SizedBox.shrink(),
      SizedBox.shrink(),
    ];
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 660,
      ),
      child: LayoutBuilder(
        builder: (context, constrains) {
          final width = constrains.maxWidth;
          final itemWidth = (width - spacing.s * 3) / 4;
          return GridView.count(
            crossAxisCount: 4,
            mainAxisSpacing: spacing.s,
            crossAxisSpacing: spacing.s,
            childAspectRatio: itemWidth / 52,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: widgets.map((widget) {
              return widget;
            }).toList(),
          );
        },
      ),
    );
  }
}
