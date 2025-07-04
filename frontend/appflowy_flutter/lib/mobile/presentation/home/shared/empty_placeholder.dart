import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/home/shared/mobile_page_card.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

class EmptySpacePlaceholder extends StatelessWidget {
  const EmptySpacePlaceholder({
    super.key,
    required this.type,
  });

  final MobilePageCardType type;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FlowySvg(
              FlowySvgs.m_empty_page_xl,
              color: theme.iconColorScheme.tertiary,
            ),
            const VSpace(12),
            Text(
              _emptyPageText,
              style: theme.textStyle.heading3.enhanced(
                color: theme.textColorScheme.secondary,
              ),
              textAlign: TextAlign.center,
            ),
            const VSpace(4),
            Text(
              _emptyPageSubText,
              style: theme.textStyle.heading4.standard(
                color: theme.textColorScheme.tertiary,
              ),
              textAlign: TextAlign.center,
            ),
            const VSpace(kBottomNavigationBarHeight + 60.0),
          ],
        ),
      ),
    );
  }

  String get _emptyPageText => switch (type) {
        MobilePageCardType.recent => LocaleKeys.sideBar_emptyRecent.tr(),
        MobilePageCardType.favorite => LocaleKeys.sideBar_emptyFavorite.tr(),
      };

  String get _emptyPageSubText => switch (type) {
        MobilePageCardType.recent =>
          LocaleKeys.sideBar_emptyRecentDescription.tr(),
        MobilePageCardType.favorite =>
          LocaleKeys.sideBar_emptyFavoriteDescription.tr(),
      };
}
