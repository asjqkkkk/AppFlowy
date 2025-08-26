import 'package:appflowy/features/settings/settings.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/drag_handle.dart';
import 'package:appflowy/plugins/database/application/cell/bloc/date_cell_editor_bloc.dart';
import 'package:appflowy/plugins/database/application/cell/cell_controller_builder.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/user/application/reminder/reminder_bloc.dart';
import 'package:appflowy/workspace/application/settings/appearance/appearance_cubit.dart';
import 'package:appflowy/workspace/presentation/widgets/date_picker/mobile_date_picker.dart';
import 'package:appflowy/workspace/presentation/widgets/date_picker/widgets/mobile_date_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MobileDateCellEditorBottomSheet extends StatelessWidget {
  const MobileDateCellEditorBottomSheet({
    super.key,
    required this.controller,
  });

  final DateCellController controller;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      snap: true,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      snapSizes: const [0.4, 0.7, 1.0],
      builder: (_, controller) => Material(
        color: Colors.transparent,
        child: ListView(
          controller: controller,
          children: [
            ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: const Center(child: DragHandle()),
            ),
            const MobileDateHeader(),
            _buildDatePicker(),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return BlocProvider(
      create: (_) => DateCellEditorBloc(
        reminderBloc: getIt<ReminderBloc>(),
        cellController: controller,
      ),
      child: BlocBuilder<DateCellEditorBloc, DateCellEditorState>(
        builder: (context, state) {
          final dateCellBloc = context.read<DateCellEditorBloc>();
          final appearanceState = context.read<AppearanceSettingsCubit>().state;

          return MobileAppFlowyDatePicker(
            dateTime: state.dateTime,
            endDateTime: state.endDateTime,
            isRange: state.isRange,
            includeTime: state.includeTime,
            dateFormat: state.dateTypeOptionPB.hasDateFormat()
                ? UserDateFormat.fromDbPB(state.dateTypeOptionPB.dateFormat)
                : appearanceState.dateFormat,
            timeFormat: state.dateTypeOptionPB.hasTimeFormat()
                ? UserTimeFormat.fromDbPB(state.dateTypeOptionPB.timeFormat)
                : appearanceState.timeFormat,
            startWeekOnMonday: appearanceState.startWeekOnMonday,
            reminderOption: state.reminderOption,
            onDaySelected: (selectedDay) {
              dateCellBloc.add(DateCellEditorEvent.updateDateTime(selectedDay));
            },
            onRangeSelected: (start, end) {
              dateCellBloc.add(DateCellEditorEvent.updateDateRange(start, end));
            },
            onIsRangeChanged: (value, dateTime, endDateTime) {
              dateCellBloc.add(
                DateCellEditorEvent.setIsRange(value, dateTime, endDateTime),
              );
            },
            onIncludeTimeChanged: (value, dateTime, endDateTime) {
              dateCellBloc.add(
                DateCellEditorEvent.setIncludeTime(
                  value,
                  dateTime,
                  endDateTime,
                ),
              );
            },
            onClearDate: () {
              dateCellBloc.add(const DateCellEditorEvent.clearDate());
            },
            onReminderSelected: (option) {
              dateCellBloc.add(DateCellEditorEvent.setReminderOption(option));
            },
          );
        },
      ),
    );
  }
}
