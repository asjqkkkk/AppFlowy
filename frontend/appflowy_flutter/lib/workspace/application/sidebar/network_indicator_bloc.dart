import 'package:appflowy/user/application/ws_connect_state_listener.dart';
import 'package:appflowy_backend/protobuf/flowy-user/workspace.pb.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'network_indicator_bloc.freezed.dart';

class NetworkIndicatorBloc
    extends Bloc<NetworkIndicatorEvent, NetworkIndicatorState> {
  NetworkIndicatorBloc({
    required String workspaceId,
  })  : _listener = WsConnectStateListener(
          workspaceId: workspaceId,
        ),
        super(
          const NetworkIndicatorState(),
        ) {
    _listener.start(
      onConnectStateChanged: (connectState) {
        if (isClosed) return;

        add(NetworkIndicatorEvent.connectStateChanged(connectState));
      },
    );

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

  @override
  Future<void> close() async {
    await _listener.stop();
    await super.close();
  }

  final WsConnectStateListener _listener;
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
