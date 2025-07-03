import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:appflowy/features/profile_setting/logic/profile_setting_bloc.dart';
import 'package:appflowy_backend/protobuf/flowy-user/workspace.pbenum.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'profile_preview_widget.dart';

class ProfileEditButton extends StatelessWidget {
  const ProfileEditButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return AFOutlinedTextButton.normal(
      text: LocaleKeys.settings_profilePage_edit.tr(),
      textStyle: theme.textStyle.body.enhanced(
        color: theme.textColorScheme.primary,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.l,
        vertical: theme.spacing.s,
      ),
      onTap: onTap,
    );
  }
}

class BannerUploadButton extends StatefulWidget {
  const BannerUploadButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<BannerUploadButton> createState() => _BannerUploadButtonState();
}

class _BannerUploadButtonState extends State<BannerUploadButton> {
  final ValueNotifier<bool> hoveringNotifier = ValueNotifier(false);

  @override
  void dispose() {
    hoveringNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (event) => hoveringNotifier.value = true,
      onExit: (event) => hoveringNotifier.value = false,
      child: GestureDetector(
        onTap: widget.onTap,
        child: ValueListenableBuilder<bool>(
          valueListenable: hoveringNotifier,
          builder: (context, hovering, child) {
            return Container(
              height: 52,
              decoration: BoxDecoration(
                border: Border.all(color: theme.borderColorScheme.primary),
                borderRadius: BorderRadius.circular(theme.spacing.m),
                color: hovering ? theme.fillColorScheme.contentHover : null,
              ),
              child: Center(
                child: FlowySvg(
                  FlowySvgs.profile_add_icon_m,
                  size: Size.square(20),
                  color: theme.iconColorScheme.primary,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class PreviewButton extends StatefulWidget {
  const PreviewButton({super.key});

  @override
  State<PreviewButton> createState() => _PreviewButtonState();
}

class _PreviewButtonState extends State<PreviewButton> {
  final popoverController = PopoverController();

  @override
  void dispose() {
    popoverController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ProfileSettingBloc>(),
        theme = AppFlowyTheme.of(context),
        isLocal = bloc.userProfile.workspaceType == WorkspaceTypePB.LocalW;
    if (isLocal) return const SizedBox.shrink();
    return AppFlowyPopover(
      direction: PopoverDirection.bottomWithCenterAligned,
      controller: popoverController,
      offset: const Offset(0, 8),
      constraints: BoxConstraints(
        maxHeight: 380,
        minWidth: 280,
        maxWidth: 280,
      ),
      margin: EdgeInsets.zero,
      decorationColor: theme.surfaceColorScheme.layer01,
      child: buildButton(),
      popupBuilder: (BuildContext popoverContext) =>
          BlocProvider.value(value: bloc, child: ProfilePreviewWidget()),
    );
  }

  Widget buildButton() {
    final theme = AppFlowyTheme.of(context), spacing = theme.spacing;
    return AFGhostButton.normal(
      onTap: () {
        popoverController.show();
      },
      builder: (context, isHover, disable) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlowySvg(
              FlowySvgs.profile_preview_icon_m,
              size: Size.square(20),
              color: theme.iconColorScheme.primary,
            ),
            HSpace(spacing.s),
            Text(
              LocaleKeys.settings_profilePage_preview.tr(),
              style: theme.textStyle.body
                  .standard(color: theme.textColorScheme.primary),
            ),
          ],
        );
      },
    );
  }
}
