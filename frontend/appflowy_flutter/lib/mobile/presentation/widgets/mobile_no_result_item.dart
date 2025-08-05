import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class MobileNoResultItem extends StatelessWidget {
  const MobileNoResultItem({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            blurRadius: 5,
            spreadRadius: 1,
            color: Colors.black.withValues(alpha: 0.1),
          ),
        ],
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: SizedBox(
        width: 240,
        height: 48,
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: Text(
                LocaleKeys.inlineActions_noResults.tr(),
                style: TextStyle(
                  fontSize: 18.0,
                  color: theme.textColorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
