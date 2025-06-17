import 'package:appflowy/workspace/application/sidebar/network_indicator_bloc.dart';
import 'package:appflowy_backend/protobuf/flowy-user/workspace.pb.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
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
            return Center(child: _icon(state.connectState!));
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
        height: 16,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator.adaptive(),
            HSpace(6),
            Text('Connecting...'),
          ],
        ),
      );
    case ConnectStatePB.WSConnected:
      return SizedBox.shrink();
    case ConnectStatePB.WSDisconnected:
      return SizedBox(
        height: 16,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: Colors.red),
            HSpace(6),
            const Text('Disconnected'),
          ],
        ),
      );
    default:
      return const SizedBox.shrink();
  }
}
