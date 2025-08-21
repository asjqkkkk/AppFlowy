import 'dart:collection';
import 'dart:io';

import 'package:appflowy/features/workspace/workspace.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/database/application/cell/bloc/select_option_cell_editor_bloc.dart';
import 'package:appflowy/plugins/database/application/cell/cell_controller_builder.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/select_option_entities.pb.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/theme_extension.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../field/type_option_editor/select/select_option_editor.dart';

import 'select_option_text_field.dart';

const double _editorPanelWidth = 300;

class SelectOptionCellEditor extends StatefulWidget {
  const SelectOptionCellEditor({
    super.key,
    required this.cellController,
  });

  final SelectOptionCellController cellController;

  @override
  State<SelectOptionCellEditor> createState() => _SelectOptionCellEditorState();
}

class _SelectOptionCellEditorState extends State<SelectOptionCellEditor> {
  final textEditingController = TextEditingController();
  final scrollController = ScrollController();
  final popoverMutex = PopoverMutex();

  late final SelectOptionCellEditorBloc bloc;
  late final FocusNode focusNode;

  @override
  void initState() {
    super.initState();

    bloc = SelectOptionCellEditorBloc(
      cellController: widget.cellController,
    );
    focusNode = FocusNode(
      onKeyEvent: (node, event) {
        switch (event.logicalKey) {
          case LogicalKeyboardKey.arrowUp when event is! KeyUpEvent:
            if (textEditingController.value.composing.isCollapsed) {
              bloc.add(const SelectOptionCellEditorEvent.focusPreviousOption());
              return KeyEventResult.handled;
            }
            break;
          case LogicalKeyboardKey.arrowDown when event is! KeyUpEvent:
            if (textEditingController.value.composing.isCollapsed) {
              bloc.add(const SelectOptionCellEditorEvent.focusNextOption());
              return KeyEventResult.handled;
            }
            break;
          case LogicalKeyboardKey.escape when event is! KeyUpEvent:
            if (!textEditingController.value.composing.isCollapsed) {
              final end = textEditingController.value.composing.end;
              final text = textEditingController.text;

              textEditingController.value = TextEditingValue(
                text: text,
                selection: TextSelection.collapsed(offset: end),
              );
              return KeyEventResult.handled;
            }
            break;
          case LogicalKeyboardKey.backspace when event is KeyDownEvent:
            if (textEditingController.text.isEmpty) {
              bloc.add(const SelectOptionCellEditorEvent.unselectLastOption());
              return KeyEventResult.handled;
            }
            break;
        }
        return KeyEventResult.ignored;
      },
    )..addListener(() {
        if (focusNode.hasFocus) {
          popoverMutex.close();
        }
      });
  }

  @override
  void dispose() {
    popoverMutex.dispose();
    textEditingController.dispose();
    scrollController.dispose();
    bloc.close();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    final isPro = context.read<UserWorkspaceBloc>().state.isInProPlan;

    return BlocProvider.value(
      value: bloc,
      child: TextFieldTapRegion(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TextField(
              textEditingController: textEditingController,
              scrollController: scrollController,
              focusNode: focusNode,
              popoverMutex: popoverMutex,
            ),
            AFDivider(
              spacing: theme.spacing.m,
            ),
            Flexible(
              child: Focus(
                descendantsAreFocusable: false,
                child: _OptionList(
                  isPro: isPro,
                  textEditingController: textEditingController,
                  popoverMutex: popoverMutex,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionList extends StatelessWidget {
  const _OptionList({
    required this.textEditingController,
    required this.popoverMutex,
    required this.isPro,
  });

  final TextEditingController textEditingController;
  final PopoverMutex popoverMutex;
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return BlocConsumer<SelectOptionCellEditorBloc,
        SelectOptionCellEditorState>(
      listenWhen: (prev, curr) => prev.clearFilter != curr.clearFilter,
      listener: (context, state) {
        if (state.clearFilter) {
          textEditingController.clear();
          context
              .read<SelectOptionCellEditorBloc>()
              .add(const SelectOptionCellEditorEvent.resetClearFilterFlag());
        }
      },
      buildWhen: (previous, current) =>
          !listEquals(previous.options, current.options) ||
          previous.createSelectOptionSuggestion !=
              current.createSelectOptionSuggestion,
      builder: (context, state) {
        return ReorderableListView.builder(
          shrinkWrap: true,
          proxyDecorator: (child, index, _) => Material(
            color: Colors.transparent,
            child: BlocProvider.value(
              value: context.read<SelectOptionCellEditorBloc>(),
              child: child,
            ),
          ),
          buildDefaultDragHandles: false,
          itemCount: state.options.length,
          onReorderStart: (_) => popoverMutex.close(),
          itemBuilder: (_, int index) {
            final option = state.options[index];
            return _SelectOptionCell(
              key: ValueKey("select_cell_option_list_${option.id}"),
              index: index,
              option: option,
              popoverMutex: popoverMutex,
              isPro: isPro,
            );
          },
          onReorder: (oldIndex, newIndex) {
            if (oldIndex < newIndex) {
              newIndex--;
            }
            final fromOptionId = state.options[oldIndex].id;
            final toOptionId = state.options[newIndex].id;
            context.read<SelectOptionCellEditorBloc>().add(
                  SelectOptionCellEditorEvent.reorderOption(
                    fromOptionId,
                    toOptionId,
                  ),
                );
          },
          header: const _Title(),
          footer: state.createSelectOptionSuggestion != null
              ? _CreateOptionCell(
                  suggestion: state.createSelectOptionSuggestion!,
                )
              : null,
          padding: EdgeInsets.only(
            left: theme.spacing.m,
            right: theme.spacing.m,
            bottom: theme.spacing.m,
          ),
        );
      },
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.textEditingController,
    required this.scrollController,
    required this.focusNode,
    required this.popoverMutex,
  });

  final TextEditingController textEditingController;
  final ScrollController scrollController;
  final FocusNode focusNode;
  final PopoverMutex popoverMutex;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SelectOptionCellEditorBloc, SelectOptionCellEditorState>(
      builder: (context, state) {
        final theme = AppFlowyTheme.of(context);

        final optionMap = LinkedHashMap<String, SelectOptionPB>.fromIterable(
          state.selectedOptions,
          key: (option) => option.name,
          value: (option) => option,
        );

        return Material(
          color: Colors.transparent,
          child: Padding(
            padding: EdgeInsets.only(
              left: theme.spacing.l,
              right: theme.spacing.l,
              top: theme.spacing.l,
              bottom: theme.spacing.xs,
            ),
            child: SelectOptionTextField(
              options: state.options,
              focusNode: focusNode,
              selectedOptionMap: optionMap,
              distanceToText: _editorPanelWidth * 0.7,
              textController: textEditingController,
              scrollController: scrollController,
              textSeparators: const [','],
              newText: (text) => context
                  .read<SelectOptionCellEditorBloc>()
                  .add(SelectOptionCellEditorEvent.filterOption(text)),
              onSubmitted: () {
                context
                    .read<SelectOptionCellEditorBloc>()
                    .add(const SelectOptionCellEditorEvent.submitTextField());
                focusNode.requestFocus();
              },
              onPaste: (tagNames, remainder) {
                context.read<SelectOptionCellEditorBloc>().add(
                      SelectOptionCellEditorEvent.selectMultipleOptions(
                        tagNames,
                        remainder,
                      ),
                    );
              },
              onRemove: (name) =>
                  context.read<SelectOptionCellEditorBloc>().add(
                        SelectOptionCellEditorEvent.unselectOption(
                          optionMap[name]!.id,
                        ),
                      ),
            ),
          ),
        );
      },
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.m,
        vertical: theme.spacing.s,
      ),
      child: Text(
        LocaleKeys.grid_selectOption_panelTitle.tr(),
        style: theme.textStyle.caption.enhanced(
          color: theme.textColorScheme.tertiary,
        ),
      ),
    );
  }
}

class _SelectOptionCell extends StatefulWidget {
  const _SelectOptionCell({
    super.key,
    required this.option,
    required this.index,
    required this.popoverMutex,
    required this.isPro,
  });

  final SelectOptionPB option;
  final int index;
  final PopoverMutex popoverMutex;
  final bool isPro;

  @override
  State<_SelectOptionCell> createState() => _SelectOptionCellState();
}

class _SelectOptionCellState extends State<_SelectOptionCell> {
  final popoverController = PopoverController();

  bool isOpen = false;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    final bloc = context.read<SelectOptionCellEditorBloc>();

    return AppFlowyPopover(
      controller: popoverController,
      margin: EdgeInsets.zero,
      asBarrier: true,
      triggerActions: PopoverTriggerFlags.none,
      constraints: BoxConstraints.loose(const Size(200, 470)),
      mutex: widget.popoverMutex,
      onClose: () => isOpen = false,
      onOpen: () => isOpen = true,
      popupBuilder: (popoverContext) {
        return SelectOptionEditor(
          key: ValueKey(widget.option.id),
          option: widget.option,
          isPro: widget.isPro,
          onDeleted: () {
            bloc.add(SelectOptionCellEditorEvent.deleteOption(widget.option));
            PopoverContainer.of(popoverContext).close();
          },
          onUpdated: (updatedOption) {
            bloc.add(SelectOptionCellEditorEvent.updateOption(updatedOption));
          },
        );
      },
      child:
          BlocBuilder<SelectOptionCellEditorBloc, SelectOptionCellEditorState>(
        builder: (context, state) {
          return MouseRegion(
            onEnter: (_) {
              bloc.add(
                SelectOptionCellEditorEvent.updateFocusedOption(
                  widget.option.id,
                ),
              );
            },
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: state.focusedOptionId == widget.option.id
                    ? theme.fillColorScheme.contentHover
                    : theme.fillColorScheme.content,
                borderRadius: const BorderRadius.all(Radius.circular(6)),
              ),
              child: SelectOptionTagCell(
                option: widget.option,
                index: widget.index,
                onSelected: _onTap,
                children: [
                  if (state.selectedOptions.contains(widget.option))
                    IgnorePointer(
                      child: FlowySvg(
                        FlowySvgs.check_s,
                        color: theme.fillColorScheme.themeThick,
                        size: const Size.square(20),
                      ),
                    ),
                  AFGhostButton.normal(
                    onTap: () {
                      if (isOpen) {
                        popoverController.close();
                      } else {
                        popoverController.show();
                        isOpen = true;
                      }
                    },
                    padding: EdgeInsets.all(2.0),
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
        },
      ),
    );
  }

  void _onTap() {
    widget.popoverMutex.close();
    final bloc = context.read<SelectOptionCellEditorBloc>();
    if (bloc.state.selectedOptions.contains(widget.option)) {
      bloc.add(SelectOptionCellEditorEvent.unselectOption(widget.option.id));
    } else {
      bloc.add(SelectOptionCellEditorEvent.selectOption(widget.option.id));
    }
  }
}

class SelectOptionTagCell extends StatelessWidget {
  const SelectOptionTagCell({
    super.key,
    required this.option,
    required this.onSelected,
    this.children = const [],
    this.index,
  });

  final SelectOptionPB option;
  final VoidCallback onSelected;
  final List<Widget> children;
  final int? index;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return GestureDetector(
      onTap: onSelected,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.m,
            vertical: theme.spacing.xs,
          ),
          child: Row(
            spacing: theme.spacing.m,
            children: [
              if (index != null)
                ReorderableDragStartListener(
                  index: index!,
                  child: MouseRegion(
                    cursor: Platform.isWindows
                        ? SystemMouseCursors.click
                        : SystemMouseCursors.grab,
                    child: SizedBox.square(
                      dimension: 20,
                      child: Center(
                        child: FlowySvg(
                          FlowySvgs.drag_element_s,
                          size: const Size.square(14),
                          color: AFThemeExtension.of(context).onBackground,
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onSelected,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: SelectOptionTag(
                      option: option,
                    ),
                  ),
                ),
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateOptionCell extends StatelessWidget {
  const _CreateOptionCell({required this.suggestion});

  final CreateSelectOptionSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return BlocBuilder<SelectOptionCellEditorBloc, SelectOptionCellEditorState>(
      builder: (context, state) {
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.m,
            vertical: theme.spacing.xs,
          ),
          decoration: BoxDecoration(
            color: state.focusedOptionId == createSelectOptionSuggestionId
                ? theme.fillColorScheme.contentHover
                : theme.fillColorScheme.content,
            borderRadius: const BorderRadius.all(Radius.circular(6)),
          ),
          child: GestureDetector(
            onTap: () => context
                .read<SelectOptionCellEditorBloc>()
                .add(const SelectOptionCellEditorEvent.createOption()),
            child: MouseRegion(
              onEnter: (_) {
                context.read<SelectOptionCellEditorBloc>().add(
                      const SelectOptionCellEditorEvent.updateFocusedOption(
                        createSelectOptionSuggestionId,
                      ),
                    );
              },
              child: Row(
                spacing: theme.spacing.xs,
                children: [
                  Text(
                    LocaleKeys.grid_selectOption_create.tr(),
                    style: theme.textStyle.body.standard(
                      color: theme.textColorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SelectOptionTag.custom(
                        name: suggestion.name,
                        color: Colors.transparent,
                        // color: selectOptionColorToBgAFColor(suggestion.color)
                        //     .toColor(theme),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
