import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/database/application/field/type_option/select_option_type_option_bloc.dart';
import 'package:appflowy/plugins/database/application/field/type_option/select_type_option_actions.dart';
import 'package:appflowy/plugins/database/widgets/cell_editor/select_option_cell_editor.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/select_option_entities.pb.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'select_option_editor.dart';

class SelectOptionTypeOptionWidget extends StatelessWidget {
  const SelectOptionTypeOptionWidget({
    super.key,
    required this.options,
    required this.beginEdit,
    required this.typeOptionAction,
    this.popoverMutex,
  });

  final List<SelectOptionPB> options;
  final VoidCallback beginEdit;
  final ISelectOptionAction typeOptionAction;
  final PopoverMutex? popoverMutex;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return BlocProvider<SelectOptionTypeOptionBloc>(
      create: (context) => SelectOptionTypeOptionBloc(
        options: options,
        typeOptionAction: typeOptionAction,
      ),
      child:
          BlocBuilder<SelectOptionTypeOptionBloc, SelectOptionTypeOptionState>(
        builder: (context, state) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.spacing.m * 2,
                  vertical: theme.spacing.xs,
                ),
                child: Text(
                  LocaleKeys.grid_field_optionTitle.tr(),
                  textAlign: TextAlign.start,
                  style: theme.textStyle.caption.enhanced(
                    color: theme.textColorScheme.tertiary,
                  ),
                ),
              ),
              if (state.isEditingOption)
                CreateOptionTextField(popoverMutex: popoverMutex)
              else
                const _AddOptionButton(),
              VSpace(
                theme.spacing.xs,
              ),
              Flexible(
                child: _OptionList(
                  popoverMutex: popoverMutex,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AddOptionButton extends StatelessWidget {
  const _AddOptionButton();

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.m,
      ),
      child: AFMenuItem(
        title: Text(
          LocaleKeys.grid_field_addSelectOption.tr(),
          style: theme.textStyle.body.standard(
            color: theme.textColorScheme.primary,
          ),
        ),
        leading: const FlowySvg(
          FlowySvgs.add_s,
          size: Size.square(20),
        ),
        onTap: () {
          context
              .read<SelectOptionTypeOptionBloc>()
              .add(const SelectOptionTypeOptionEvent.addingOption());
        },
      ),
    );
  }
}

class CreateOptionTextField extends StatefulWidget {
  const CreateOptionTextField({super.key, this.popoverMutex});

  final PopoverMutex? popoverMutex;

  @override
  State<CreateOptionTextField> createState() => _CreateOptionTextFieldState();
}

class _CreateOptionTextFieldState extends State<CreateOptionTextField> {
  final focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    focusNode.addListener(_onFocusChanged);
    widget.popoverMutex?.addPopoverListener(_onPopoverChanged);
  }

  @override
  void dispose() {
    widget.popoverMutex?.removePopoverListener(_onPopoverChanged);
    focusNode.removeListener(_onFocusChanged);
    focusNode.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SelectOptionTypeOptionBloc, SelectOptionTypeOptionState>(
      builder: (context, state) {
        final text = state.newOptionName ?? '';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0),
          child: FlowyTextField(
            autoClearWhenDone: true,
            text: text,
            focusNode: focusNode,
            onCanceled: () {
              context
                  .read<SelectOptionTypeOptionBloc>()
                  .add(const SelectOptionTypeOptionEvent.endAddingOption());
            },
            onEditingComplete: () {},
            onSubmitted: (optionName) {
              context
                  .read<SelectOptionTypeOptionBloc>()
                  .add(SelectOptionTypeOptionEvent.createOption(optionName));
            },
          ),
        );
      },
    );
  }

  void _onFocusChanged() {
    if (focusNode.hasFocus) {
      widget.popoverMutex?.close();
    }
  }

  void _onPopoverChanged() {
    if (focusNode.hasFocus) {
      focusNode.unfocus();
    }
  }
}

class _OptionList extends StatelessWidget {
  const _OptionList({
    this.popoverMutex,
  });

  final PopoverMutex? popoverMutex;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SelectOptionTypeOptionBloc, SelectOptionTypeOptionState>(
      builder: (context, state) {
        return ReorderableListView.builder(
          shrinkWrap: true,
          onReorderStart: (_) => popoverMutex?.close(),
          proxyDecorator: (child, index, _) => Material(
            color: Colors.transparent,
            child: BlocProvider.value(
              value: context.read<SelectOptionTypeOptionBloc>(),
              child: child,
            ),
          ),
          buildDefaultDragHandles: false,
          itemBuilder: (context, index) => _OptionCell(
            key: ValueKey("select_type_option_list_${state.options[index].id}"),
            index: index,
            option: state.options[index],
            popoverMutex: popoverMutex,
          ),
          itemCount: state.options.length,
          onReorder: (oldIndex, newIndex) {
            if (oldIndex < newIndex) {
              newIndex--;
            }
            final fromOptionId = state.options[oldIndex].id;
            final toOptionId = state.options[newIndex].id;
            context.read<SelectOptionTypeOptionBloc>().add(
                  SelectOptionTypeOptionEvent.reorderOption(
                    fromOptionId,
                    toOptionId,
                  ),
                );
          },
          padding: EdgeInsets.symmetric(horizontal: 8.0),
        );
      },
    );
  }
}

class _OptionCell extends StatefulWidget {
  const _OptionCell({
    super.key,
    required this.option,
    required this.index,
    this.popoverMutex,
  });

  final SelectOptionPB option;
  final int index;
  final PopoverMutex? popoverMutex;

  @override
  State<_OptionCell> createState() => _OptionCellState();
}

class _OptionCellState extends State<_OptionCell> {
  final popoverController = PopoverController();

  @override
  Widget build(BuildContext context) {
    return AppFlowyPopover(
      controller: popoverController,
      mutex: widget.popoverMutex,
      margin: EdgeInsets.zero,
      asBarrier: true,
      triggerActions: PopoverTriggerFlags.none,
      constraints: BoxConstraints.loose(const Size(200, 470)),
      child: _OptionCellChild(
        option: widget.option,
        index: widget.index,
        onTap: () => popoverController.show(),
      ),
      popupBuilder: (popoverContext) {
        return SelectOptionEditor(
          option: widget.option,
          onDeleted: () {
            context
                .read<SelectOptionTypeOptionBloc>()
                .add(SelectOptionTypeOptionEvent.deleteOption(widget.option));
            PopoverContainer.of(popoverContext).close();
          },
          onUpdated: (updatedOption) {
            context
                .read<SelectOptionTypeOptionBloc>()
                .add(SelectOptionTypeOptionEvent.updateOption(updatedOption));
          },
          key: ValueKey(widget.option.id),
        );
      },
    );
  }
}

class _OptionCellChild extends StatefulWidget {
  const _OptionCellChild({
    required this.option,
    required this.index,
    required this.onTap,
  });

  final SelectOptionPB option;
  final int? index;
  final VoidCallback onTap;

  @override
  State<_OptionCellChild> createState() => _OptionCellChildState();
}

class _OptionCellChildState extends State<_OptionCellChild> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      cursor: SystemMouseCursors.click,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isHovered
              ? theme.fillColorScheme.contentHover
              : theme.fillColorScheme.content,
          borderRadius: const BorderRadius.all(Radius.circular(6)),
        ),
        child: SelectOptionTagCell(
          option: widget.option,
          index: widget.index,
          onSelected: widget.onTap,
          children: [
            AFGhostButton.normal(
              onTap: widget.onTap,
              padding: const EdgeInsets.all(2.0),
              builder: (context, isHovering, disabled) {
                return FlowySvg(
                  FlowySvgs.three_dots_s,
                  size: const Size.square(20),
                  color: theme.iconColorScheme.tertiary,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
