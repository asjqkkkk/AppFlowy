import 'dart:async';

import 'package:appflowy/user/application/ws_connect_state_listener.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-user/workspace.pb.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'network_indicator_bloc.freezed.dart';

class NetworkIndicatorBloc
    extends Bloc<NetworkIndicatorEvent, NetworkIndicatorState> {
  NetworkIndicatorBloc({
    required String workspaceId,
  })  : _listener = WsConnectStateListener(workspaceId: workspaceId),
        super(const NetworkIndicatorState()) {
    _listener.start(
      onConnectStateChanged: (connectState) {
        if (isClosed) return;

        add(NetworkIndicatorEvent.connectStateChanged(connectState));
      },
    );

    _checkConnectionState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkConnectionState();
    });

    on<NetworkIndicatorEvent>((event, emit) async {
      await event.when(
        connectStateChanged: (connectState) async => emit(
          state.copyWith(
            connectState: connectState,
          ),
        ),
        reconnect: () async {
          await UserEventStartWSConnect().send();
        },
      );
    });
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await _listener.stop();
    await super.close();
  }

  final WsConnectStateListener _listener;
  Timer? _timer;

  void _checkConnectionState() {
    UserEventGetWSConnectState().send().then((value) {
      if (isClosed) return;
      value.fold(
        (data) => add(NetworkIndicatorEvent.connectStateChanged(data.state)),
        (error) => Log.error(error.toString()),
      );
    });
  }
}

@freezed
class NetworkIndicatorEvent with _$NetworkIndicatorEvent {
  const factory NetworkIndicatorEvent.connectStateChanged(
    ConnectStatePB connectState,
  ) = _ConnectStateChanged;

  const factory NetworkIndicatorEvent.reconnect() = _Reconnect;
}

@freezed
class NetworkIndicatorState with _$NetworkIndicatorState {
  const factory NetworkIndicatorState({
    ConnectStatePB? connectState,
  }) = _NetworkIndicatorState;
}
