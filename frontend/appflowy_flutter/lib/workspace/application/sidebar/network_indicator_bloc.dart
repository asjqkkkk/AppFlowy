import 'package:appflowy_backend/protobuf/flowy-user/workspace.pb.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'network_indicator_bloc.freezed.dart';

class NetworkIndicatorBloc
    extends Bloc<NetworkIndicatorEvent, NetworkIndicatorState> {
  NetworkIndicatorBloc()
      : super(
          const NetworkIndicatorState(),
        ) {
    on<NetworkIndicatorEvent>((event, emit) {
      event.when(
        connectStateChanged: (connectState) => emit(
          state.copyWith(
            connectState: connectState,
          ),
        ),
      );
    });
  }
}

@freezed
class NetworkIndicatorEvent with _$NetworkIndicatorEvent {
  const factory NetworkIndicatorEvent.connectStateChanged(
    ConnectStatePB connectState,
  ) = _ConnectStateChanged;
}

@freezed
class NetworkIndicatorState with _$NetworkIndicatorState {
  const factory NetworkIndicatorState({
    ConnectStatePB? connectState,
  }) = _NetworkIndicatorState;
}
