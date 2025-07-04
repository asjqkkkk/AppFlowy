import 'package:appflowy/features/profile_setting/data/banner.dart';
import 'package:appflowy/features/profile_setting/logic/profile_setting_bloc.dart';
import 'package:appflowy/features/profile_setting/logic/profile_setting_event.dart';
import 'package:appflowy/features/profile_setting/logic/profile_setting_state.dart';
import 'package:appflowy/features/profile_setting/presentation/widgets/banner_widget.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/show_mobile_bottom_sheet.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'mobile_banner_uploader.dart';

void showMobileContactDetailMenu(BuildContext context) {
  final theme = AppFlowyTheme.of(context);
  showMobileBottomSheet(
    context,
    showDragHandle: true,
    showDivider: false,
    enableDraggableScrollable: true,
    initialChildSize: 0.95,
    minChildSize: 0.95,
    maxChildSize: 0.95,
    backgroundColor: theme.surfaceColorScheme.primary,
    builder: (_) => BlocProvider.value(
      value: context.read<ProfileSettingBloc>(),
      child: MobileEditBannerBottomSheet(),
    ),
  );
}

class MobileEditBannerBottomSheet extends StatelessWidget {
  const MobileEditBannerBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context), spacing = theme.spacing;
    return BlocBuilder<ProfileSettingBloc, ProfileSettingState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            BottomSheetHeader(
              showBackButton: false,
              showDoneButton: false,
              showCloseButton: true,
              showRemoveButton: false,
              title: LocaleKeys.settings_profilePage_editBannerImage.tr(),
              // doneButtonBuilder: (context) {
              //   return BottomSheetDoneButton(
              //     text: LocaleKeys.button_save.tr(),
              //     onDone: () {},
              //   );
              // },
            ),
            Padding(
              padding: EdgeInsets.all(spacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...buildCustomBanner(context),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> buildCustomBanner(BuildContext context) {
    final theme = AppFlowyTheme.of(context), spacing = theme.spacing;
    final bloc = context.read<ProfileSettingBloc>(),
        profile = bloc.state.profile,
        hasCustomBanner = profile.customBanner != null;
    return [
      Row(
        children: [
          Text(
            LocaleKeys.settings_profilePage_customImage.tr(),
            style: theme.textStyle.caption
                .prominent(color: theme.textColorScheme.secondary),
          ),
          if (hasCustomBanner) ...[
            Spacer(),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                bloc.add(ProfileSettingEvent.uploadBanner(null));
              },
              child: Text(
                LocaleKeys.button_clear.tr(),
                style: theme.textStyle.caption
                    .enhanced(color: theme.textColorScheme.secondary),
              ),
            ),
          ],
        ],
      ),
      VSpace(spacing.xs),
      MobileBannerUploader(),
      VSpace(spacing.xl),
      Text(
        LocaleKeys.settings_profilePage_wallpapers.tr(),
        style: theme.textStyle.caption
            .prominent(color: theme.textColorScheme.secondary),
      ),
      VSpace(spacing.xs),
      LayoutBuilder(
        builder: (context, constrains) {
          final width = constrains.maxWidth;
          final itemWidth = (width - spacing.s) / 2;
          return GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: spacing.s,
            crossAxisSpacing: spacing.s,
            childAspectRatio: itemWidth / 72,
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
                    selected: banner == bloc.state.selectedBanner,
                    isDefault: index == 0,
                    size: Size(itemWidth, 72),
                  ),
                ),
              );
            }),
          );
        },
      ),
    ];
  }
}
