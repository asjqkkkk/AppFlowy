import 'dart:async';

import 'package:appflowy/core/notification/folder_notification.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/notification.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-notification/subject.pb.dart';
import 'package:appflowy_backend/rust_stream.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:flutter/foundation.dart';

typedef RecentViewsUpdated = void Function(
  FlowyResult<void, FlowyError> result,
);

class RecentViewsListener {
  RecentViewsListener({
    required this.workspaceId,
  });

  StreamSubscription<SubscribeObject>? _streamSubscription;
  FolderNotificationParser? _parser;

  RecentViewsUpdated? _recentViewsUpdated;
  final String workspaceId;

  void start({
    RecentViewsUpdated? recentViewsUpdated,
  }) {
    _recentViewsUpdated = recentViewsUpdated;
    _parser = FolderNotificationParser(
      id: workspaceId,
      callback: _observableCallback,
    );
    _streamSubscription = RustStreamReceiver.listen(
      (observable) => _parser?.parse(observable),
    );
  }

  void _observableCallback(
    FolderNotification ty,
    FlowyResult<Uint8List, FlowyError> result,
  ) {
    if (_recentViewsUpdated == null) {
      return;
    }

    result.fold(
      (payload) {
        _recentViewsUpdated?.call(
          FlowyResult.success(null),
        );
      },
      (error) => _recentViewsUpdated?.call(
        FlowyResult.failure(error),
      ),
    );
  }

  Future<void> stop() async {
    _parser = null;
    await _streamSubscription?.cancel();
    _recentViewsUpdated = null;
  }
}
