import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_popover/appflowy_popover.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../block_action_option_cubit.dart';
import 'option_actions.dart';

class DeleteOptionButton extends StatelessWidget {
  const DeleteOptionButton({
    super.key,
    required this.controller,
    required this.blockComponentContext,
  });

  final BlockComponentContext blockComponentContext;
  final PopoverController controller;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return AFGhostButton.normal(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.m,
        vertical: theme.spacing.s,
      ),
      builder: (context, isHovering, disabled) {
        return Row(
          spacing: theme.spacing.m,
          children: [
            FlowySvg(
              FlowySvgs.trash_s,
              size: const Size.square(16),
              color: isHovering
                  ? theme.textColorScheme.error
                  : theme.iconColorScheme.primary,
            ),
            Expanded(
              child: Text(
                LocaleKeys.button_delete.tr(),
                style: theme.textStyle.body.standard(
                  color: isHovering
                      ? theme.textColorScheme.error
                      : theme.textColorScheme.primary,
                ),
              ),
            ),
          ],
        );
      },
      onTap: () {
        context.read<BlockActionOptionCubit>().handleAction(
              OptionAction.delete,
              blockComponentContext.node,
            );
        controller.close();
      },
    );
  }
}
