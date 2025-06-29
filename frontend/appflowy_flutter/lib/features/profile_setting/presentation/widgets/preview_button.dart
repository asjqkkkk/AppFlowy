import 'package:appflowy/features/profile_setting/logic/profile_setting_bloc.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'profile_preview_widget.dart';

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
        theme = AppFlowyTheme.of(context);
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

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {},
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: spacing.xs,
            horizontal: spacing.m,
          ),
          child: Row(
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
          ),
        ),
      ),
    );
  }
}
