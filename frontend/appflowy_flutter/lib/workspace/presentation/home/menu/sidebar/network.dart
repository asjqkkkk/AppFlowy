import 'package:appflowy/workspace/application/sidebar/network_indicator_bloc.dart';
import 'package:appflowy_backend/protobuf/flowy-user/workspace.pb.dart';
import 'package:flowy_infra_ui/style_widget/button.dart';
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
            return Center(child: _icon(state.connectState!, context));
          }
        },
      ),
    );
  }
}

Widget _icon(ConnectStatePB connectState, BuildContext context) {
  switch (connectState) {
    case ConnectStatePB.WSConnecting:
      return const SizedBox(
        height: 26,
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
        height: 26,
        child: FlowyButton(
          radius: BorderRadius.zero,
          text: Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off, color: Colors.red, size: 16),
                HSpace(6),
                Text('Click to reconnect'),
              ],
            ),
          ),
          onTap: () {
            context
                .read<NetworkIndicatorBloc>()
                .add(const NetworkIndicatorEvent.reconnect());
          },
        ),
      );
    default:
      return const SizedBox.shrink();
  }
}
