import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/widgets.dart';

class PreviewButton extends StatefulWidget {
  const PreviewButton({super.key});

  @override
  State<PreviewButton> createState() => _PreviewButtonState();
}

class _PreviewButtonState extends State<PreviewButton> {
  @override
  Widget build(BuildContext context) {
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
