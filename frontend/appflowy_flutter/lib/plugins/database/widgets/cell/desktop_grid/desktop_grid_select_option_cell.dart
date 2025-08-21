import 'package:appflowy/features/workspace/workspace.dart';
import 'package:appflowy/plugins/database/application/cell/bloc/select_option_cell_bloc.dart';
import 'package:appflowy/plugins/database/grid/presentation/layout/sizes.dart';
import 'package:appflowy/plugins/database/widgets/cell_editor/select_option_cell_editor.dart';
import 'package:appflowy/plugins/database/widgets/field/type_option_editor/select/select_option_editor.dart';
import 'package:appflowy/plugins/database/widgets/row/cells/cell_container.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../editable_cell_skeleton/select_option.dart';

class DesktopGridSelectOptionCellSkin extends IEditableSelectOptionCellSkin {
  @override
  Widget build(
    BuildContext context,
    CellContainerNotifier cellContainerNotifier,
    ValueNotifier<bool> compactModeNotifier,
    SelectOptionCellBloc bloc,
    PopoverController popoverController,
  ) {
    return AppFlowyPopover(
      controller: popoverController,
      constraints: const BoxConstraints.tightFor(width: 300),
      margin: EdgeInsets.zero,
      triggerActions: PopoverTriggerFlags.none,
      direction: PopoverDirection.bottomWithLeftAligned,
      popupBuilder: (popoverContext) {
        return BlocProvider.value(
          value: context.read<UserWorkspaceBloc>(),
          child: SelectOptionCellEditor(
            cellController: bloc.cellController,
          ),
        );
      },
      onClose: () => cellContainerNotifier.isFocus = false,
      child: BlocBuilder<SelectOptionCellBloc, SelectOptionCellState>(
        builder: (context, state) {
          return Align(
            alignment: AlignmentDirectional.centerStart,
            child: state.wrap
                ? _buildWrapOptions(
                    context,
                    state.selectedOptions,
                    compactModeNotifier,
                  )
                : _buildNoWrapOptions(
                    context,
                    state.selectedOptions,
                    compactModeNotifier,
                  ),
          );
        },
      ),
    );
  }

  Widget _buildWrapOptions(
    BuildContext context,
    List<SelectOptionPB> options,
    ValueNotifier<bool> compactModeNotifier,
  ) {
    return ValueListenableBuilder(
      valueListenable: compactModeNotifier,
      builder: (context, compactMode, _) {
        final padding = compactMode
            ? GridSize.compactCellContentInsets
            : GridSize.cellContentInsets;
        return Padding(
          padding: padding,
          child: Wrap(
            runSpacing: 4,
            spacing: 4,
            children: options.map(
              (option) {
                return SelectOptionTag(
                  option: option,
                );
              },
            ).toList(),
          ),
        );
      },
    );
  }

  Widget _buildNoWrapOptions(
    BuildContext context,
    List<SelectOptionPB> options,
    ValueNotifier<bool> compactModeNotifier,
  ) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      scrollDirection: Axis.horizontal,
      child: ValueListenableBuilder(
        valueListenable: compactModeNotifier,
        builder: (context, compactMode, _) {
          final padding = compactMode
              ? GridSize.compactCellContentInsets
              : GridSize.cellContentInsets;
          return Padding(
            padding: padding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4.0,
              children: options
                  .map(
                    (option) => SelectOptionTag(
                      option: option,
                    ),
                  )
                  .toList(),
            ),
          );
        },
      ),
    );
  }
}
