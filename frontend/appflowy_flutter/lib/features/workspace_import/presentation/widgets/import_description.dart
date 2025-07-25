import 'package:appflowy/features/workspace_import/logic/workspace_import_dialog_bloc.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ImportDescription extends StatelessWidget {
  const ImportDescription({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.xxl,
        vertical: theme.spacing.m,
      ),
      child: RichText(
        text: TextSpan(
          style: theme.textStyle.body.standard(
            color: theme.textColorScheme.primary,
          ),
          children: [
            TextSpan(
              text: LocaleKeys.workspaceImport_description.tr(),
            ),
            TextSpan(
              text: LocaleKeys.workspaceImport_learnMore.tr(),
              style: theme.textStyle.body.standard(
                color: theme.textColorScheme.action,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  context.read<WorkspaceImportDialogBloc>().add(
                        const LearnMoreClicked(),
                      );
                },
            ),
          ],
        ),
      ),
    );
  }
}
