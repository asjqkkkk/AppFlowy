import 'package:appflowy/features/workspace/workspace.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/actions/block_action_option_cubit.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/actions/option/option_actions.dart';
import 'package:appflowy/workspace/application/settings/appearance/appearance_cubit.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'drag_to_reorder/draggable_option_button.dart';
import 'option/delete_option_action.dart';

class BlockOptionButton extends StatefulWidget {
  const BlockOptionButton({
    super.key,
    required this.blockComponentContext,
    required this.blockComponentState,
    required this.actions,
    required this.editorState,
    required this.blockComponentBuilder,
  });

  final BlockComponentContext blockComponentContext;
  final BlockComponentActionState blockComponentState;
  final List<OptionAction> actions;
  final EditorState editorState;
  final Map<String, BlockComponentBuilder> blockComponentBuilder;

  @override
  State<BlockOptionButton> createState() => _BlockOptionButtonState();
}

class _BlockOptionButtonState extends State<BlockOptionButton> {
  // the mutex is used to ensure that only one popover is open at a time
  // for example, when the user is selecting the color, the turn into option
  // should not be shown.
  final mutex = PopoverMutex();
  final controller = PopoverController();

  @override
  Widget build(BuildContext context) {
    final direction =
        context.read<AppearanceSettingsCubit>().state.layoutDirection ==
                LayoutDirection.rtlLayout
            ? PopoverDirection.rightWithCenterAligned
            : PopoverDirection.leftWithCenterAligned;
    return BlocProvider(
      create: (context) => BlockActionOptionCubit(
        editorState: widget.editorState,
        blockComponentBuilder: widget.blockComponentBuilder,
      ),
      child: BlocBuilder<BlockActionOptionCubit, BlockActionOptionState>(
        builder: (context, _) {
          return AppFlowyPopover(
            popupBuilder: (popoverContext) {
              _onPopoverBuilder();

              return MultiBlocProvider(
                providers: [
                  BlocProvider.value(
                    value: context.read<BlockActionOptionCubit>(),
                  ),
                  BlocProvider.value(
                    value: context.read<UserWorkspaceBloc>(),
                  ),
                ],
                child: IntrinsicHeight(
                  child: Column(
                    children: _buildPopoverActions(context),
                  ),
                ),
              );
            },
            animationDuration: Durations.short3,
            controller: controller,
            beginScaleFactor: 1.0,
            beginOpacity: 0.8,
            direction: direction,
            triggerActions: PopoverTriggerFlags.none,
            constraints: BoxConstraints(
              maxWidth: 240,
              maxHeight: 700,
            ),
            margin: EdgeInsets.all(AppFlowyTheme.of(context).spacing.m),
            onClose: () => _onPopoverClosed(context),
            child: DraggableOptionButton(
              controller: controller,
              editorState: widget.editorState,
              blockComponentContext: widget.blockComponentContext,
              blockComponentBuilder: widget.blockComponentBuilder,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    mutex.dispose();
    super.dispose();
  }

  List<Widget> _buildPopoverActions(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return widget.actions.map((e) {
      return switch (e) {
        OptionAction.divider => AFDivider(
            spacing: theme.spacing.m,
          ),
        OptionAction.color => ColorOptionButton(
            editorState: widget.editorState,
            controller: controller,
            mutex: mutex,
          ),
        OptionAction.align => AlignOptionButton(
            editorState: widget.editorState,
            controller: controller,
            mutex: mutex,
          ),
        OptionAction.depth => DepthOptionButton(
            editorState: widget.editorState,
            controller: controller,
            mutex: mutex,
          ),
        OptionAction.turnInto => TurnIntoButton(
            editorState: widget.editorState,
            blockComponentBuilder: widget.blockComponentBuilder,
            mutex: mutex,
          ),
        OptionAction.delete => DeleteOptionButton(
            controller: controller,
            blockComponentContext: widget.blockComponentContext,
          ),
        _ => AFMenuItem(
            leading: FlowySvg(
              e.svg,
              color: theme.iconColorScheme.primary,
            ),
            title: Text(
              e.description,
              style: theme.textStyle.body.standard(
                color: theme.textColorScheme.primary,
              ),
            ),
            onTap: () {
              context
                  .read<BlockActionOptionCubit>()
                  .handleAction(e, widget.blockComponentContext.node);
              controller.close();
            },
          ),
      };
    }).toList();
  }

  void _onPopoverBuilder() {
    keepEditorFocusNotifier.increase();
    widget.blockComponentState.alwaysShowActions = true;
  }

  void _onPopoverClosed(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      widget.editorState.selectionType = null;
      widget.editorState.selection = null;
      widget.blockComponentState.alwaysShowActions = false;
    });

    PopoverContainer.maybeOf(context)?.closeAll();
  }
}
