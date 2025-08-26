import 'dart:async';

import 'package:appflowy/plugins/database/application/cell/cell_controller_builder.dart';
import 'package:appflowy/plugins/database/application/field/field_info.dart';
import 'package:appflowy/util/int64_extension.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/timestamp_entities.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

class TimestampCellBloc extends Bloc<TimestampCellEvent, TimestampCellState> {
  TimestampCellBloc({
    required this.cellController,
  }) : super(TimestampCellState.initial(cellController)) {
    on<DidReceiveCellUpdate>(_onDidReceiveCellUpdate);
    on<DidUpdateField>(_onDidUpdateField);
    _startListening();
  }

  final TimestampCellController cellController;
  void Function()? _onCellChangedFn;

  @override
  Future<void> close() async {
    if (_onCellChangedFn != null) {
      cellController.removeListener(
        onCellChanged: _onCellChangedFn!,
        onFieldChanged: _onFieldChangedListener,
      );
    }
    await cellController.dispose();
    return super.close();
  }

  Future<void> _onDidReceiveCellUpdate(
    DidReceiveCellUpdate event,
    Emitter<TimestampCellState> emit,
  ) async {
    emit(
      state.copyWith(
        dateTime: event.data?.timestamp.toDateTime(),
      ),
    );
  }

  Future<void> _onDidUpdateField(
    DidUpdateField event,
    Emitter<TimestampCellState> emit,
  ) async {
    final wrap = event.fieldInfo.wrapCellContent;
    if (wrap != null) {
      emit(state.copyWith(wrap: wrap));
    }
  }

  void _startListening() {
    _onCellChangedFn = cellController.addListener(
      onCellChanged: (data) {
        if (!isClosed) {
          add(TimestampCellEvent.didReceiveCellUpdate(data));
        }
      },
      onFieldChanged: _onFieldChangedListener,
    );
  }

  void _onFieldChangedListener(FieldInfo fieldInfo) {
    if (!isClosed) {
      add(TimestampCellEvent.didUpdateField(fieldInfo));
    }
  }
}

sealed class TimestampCellEvent {
  const TimestampCellEvent();

  factory TimestampCellEvent.didReceiveCellUpdate(TimestampCellDataPB? data) =
      DidReceiveCellUpdate;
  factory TimestampCellEvent.didUpdateField(FieldInfo fieldInfo) =
      DidUpdateField;
}

class DidReceiveCellUpdate extends TimestampCellEvent {
  const DidReceiveCellUpdate(this.data);

  final TimestampCellDataPB? data;
}

class DidUpdateField extends TimestampCellEvent {
  const DidUpdateField(this.fieldInfo);

  final FieldInfo fieldInfo;
}

class TimestampCellState extends Equatable {
  const TimestampCellState({
    required this.dateTime,
    required this.fieldInfo,
    required this.wrap,
  });

  factory TimestampCellState.initial(TimestampCellController cellController) {
    final cellData = cellController.getCellData();
    final wrap = cellController.fieldInfo.wrapCellContent;

    return TimestampCellState(
      fieldInfo: cellController.fieldInfo,
      dateTime: (cellData?.timestamp ?? Int64()).toDateTime(),
      wrap: wrap ?? true,
    );
  }

  final DateTime dateTime;
  final FieldInfo fieldInfo;
  final bool wrap;

  TimestampCellState copyWith({
    DateTime? dateTime,
    FieldInfo? fieldInfo,
    bool? wrap,
  }) {
    return TimestampCellState(
      dateTime: dateTime ?? this.dateTime,
      fieldInfo: fieldInfo ?? this.fieldInfo,
      wrap: wrap ?? this.wrap,
    );
  }

  @override
  List<Object?> get props => [dateTime, fieldInfo, wrap];
}
