import 'package:appflowy/plugins/database/application/cell/bloc/timestamp_cell_bloc.dart';
import 'package:appflowy/plugins/database/widgets/row/cells/cell_container.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

import '../editable_cell_skeleton/timestamp.dart';

class MobileRowDetailTimestampCellSkin extends IEditableTimestampCellSkin {
  @override
  Widget build(
    BuildContext context,
    CellContainerNotifier cellContainerNotifier,
    ValueNotifier<bool> compactModeNotifier,
    TimestampCellBloc bloc,
    TimestampCellState state,
  ) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 48,
        minWidth: double.infinity,
      ),
      decoration: BoxDecoration(
        border: Border.fromBorderSide(
          BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      child: FlowyText(
        getTimestampCellText(
          context,
          state.fieldInfo,
          state.dateTime,
        ),
        fontSize: 16,
        maxLines: null,
      ),
    );
  }
}
