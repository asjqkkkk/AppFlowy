import 'package:appflowy/workspace/application/sidebar/network_indicator_bloc.dart';
import 'package:appflowy_backend/protobuf/flowy-user/workspace.pb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WebSocketIndicator extends StatelessWidget {
  const WebSocketIndicator({super.key, required this.workspaceId});
  final String workspaceId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NetworkIndicatorBloc(workspaceId: workspaceId),
      child: BlocBuilder<NetworkIndicatorBloc, NetworkIndicatorState>(
        builder: (context, state) {
          if (state.connectState == null) {
            return const SizedBox.shrink();
          } else {
            return SizedBox(
              height: 20,
              child: Center(child: _icon(state.connectState!)),
            );
          }
        },
      ),
    );
  }
}

Widget _icon(ConnectStatePB connectState) {
  switch (connectState) {
    case ConnectStatePB.WSConnecting:
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
        ),
      );
    case ConnectStatePB.WSConnected:
      return const Icon(Icons.wifi, color: Colors.green);
    case ConnectStatePB.WSDisconnected:
      return const Icon(Icons.wifi_off, color: Colors.red);
    default:
      return const SizedBox.shrink();
  }
}
