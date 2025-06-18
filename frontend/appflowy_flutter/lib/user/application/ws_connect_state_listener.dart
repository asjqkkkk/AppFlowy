import 'dart:async';
import 'dart:typed_data';

import 'package:appflowy/core/notification/user_notification.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-notification/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-user/notification.pb.dart'
    as user;
import 'package:appflowy_backend/protobuf/flowy-user/workspace.pb.dart';
import 'package:appflowy_backend/rust_stream.dart';
import 'package:appflowy_result/appflowy_result.dart';

class WsConnectStateListener {
  WsConnectStateListener({
    required this.workspaceId,
  });

  StreamSubscription<SubscribeObject>? _subscription;
  UserNotificationParser? _userParser;
  void Function(ConnectStatePB)? onConnectStateChanged;
  final String workspaceId;

  void start({
    void Function(ConnectStatePB)? onConnectStateChanged,
  }) {
    this.onConnectStateChanged = onConnectStateChanged;
    _userParser = UserNotificationParser(
      id: workspaceId,
      callback: _userNotificationCallback,
    );
    _subscription = RustStreamReceiver.listen((observable) {
      _userParser?.parse(observable);
    });
  }

  Future<void> stop() async {
    _userParser = null;
    await _subscription?.cancel();
  }

  void _userNotificationCallback(
    user.UserNotification ty,
    FlowyResult<Uint8List, FlowyError> result,
  ) {
    switch (ty) {
      case user.UserNotification.WebSocketConnectState:
        result.fold(
          (payload) {
            final pb = ConnectStateNotificationPB.fromBuffer(payload);
            onConnectStateChanged?.call(pb.state);
          },
          (r) => Log.error(r),
        );
        break;
      default:
        break;
    }
  }
}
