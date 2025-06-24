import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class RestrictedAccessSection extends StatelessWidget {
  const RestrictedAccessSection({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return AFMenuSection(
      title: LocaleKeys.shareTab_generalAccess.tr(),
      padding: EdgeInsets.symmetric(
        vertical: theme.spacing.xs,
        horizontal: theme.spacing.m,
      ),
      children: [
        AFMenuItem(
          cursor: SystemMouseCursors.basic,
          padding: EdgeInsets.symmetric(
            vertical: theme.spacing.s,
            horizontal: theme.spacing.m,
          ),
          leading: Container(
            padding: EdgeInsets.all(theme.spacing.xs),
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.borderColorScheme.primary,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
              borderRadius: BorderRadius.all(
                Radius.circular(6),
              ),
            ),
            child: FlowySvg(
              FlowySvgs.restricted_access_m,
              color: theme.textColorScheme.secondary,
            ),
          ),
          title: Text(
            LocaleKeys.shareTab_restricted.tr(),
            style: theme.textStyle.body.standard(
              color: theme.textColorScheme.primary,
            ),
          ),
          subtitle: Text(
            LocaleKeys.shareTab_onlyPeopleWithAccessCanOpenWithTheLink.tr(),
            style: theme.textStyle.caption.standard(
              color: theme.textColorScheme.secondary,
            ),
          ),
          onTap: () {},
        ),
      ],
    );
  }
}
