import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/workspace/presentation/widgets/pop_up_action.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_popover/appflowy_popover.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../block_action_option_cubit.dart';
import 'option_actions.dart';

class DeleteOptionAction extends CustomActionCell {
  DeleteOptionAction({
    required this.blockComponentContext,
  });

  final BlockComponentContext blockComponentContext;

  @override
  Widget buildWithContext(
    BuildContext context,
    PopoverController controller,
    PopoverMutex? mutex,
  ) {
    final theme = AppFlowyTheme.of(context);

    return AFGhostButton.normal(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      builder: (context, isHovering, disabled) {
        return Row(
          spacing: 10,
          children: [
            FlowySvg(
              FlowySvgs.trash_s,
              size: const Size.square(16),
              color: isHovering ? theme.textColorScheme.error : null,
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
