import 'dart:async';

import 'package:appflowy/core/notification/folder_notification.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/notification.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:flowy_infra/notifier.dart';
import 'package:flutter/foundation.dart';

typedef MentionablePersonsNotifyValue
    = FlowyResult<MentionablePersonChangeSetPB, FlowyError>;
typedef MentionablePersonsReloadedNotifyValue
    = FlowyResult<GetMentionablePersonsResponsePB, FlowyError>;

typedef SharedUsersNotifyValue = FlowyResult<List<SharedUserPB>, FlowyError>;

/// The [WorkspaceMentionableListener] listens to the changes including the below:
///
/// - The mentionable persons of the workspace.
/// - Individual mentionable person updates.
class WorkspaceMentionableListener {
  WorkspaceMentionableListener({required this.workspaceId});

  final String workspaceId;

  PublishNotifier<MentionablePersonsNotifyValue>? _mentionablePersonsNotifier =
      PublishNotifier();
  PublishNotifier<MentionablePersonsReloadedNotifyValue>?
      _mentionablePersonsReloadedNotifier = PublishNotifier();

  FolderNotificationListener? _listener;

  void start({
    ValueChanged<MentionablePersonsNotifyValue>? mentionablePersonsChanged,
    ValueChanged<MentionablePersonsReloadedNotifyValue>?
        mentionablePersonsReloaded,
  }) {
    if (mentionablePersonsChanged != null) {
      _mentionablePersonsNotifier
          ?.addPublishListener(mentionablePersonsChanged);
    }

    if (mentionablePersonsReloaded != null) {
      _mentionablePersonsReloadedNotifier
          ?.addPublishListener(mentionablePersonsReloaded);
    }

    _listener = FolderNotificationListener(
      objectId: workspaceId,
      handler: _handleObservableType,
    );
  }

  void _handleObservableType(
    FolderNotification ty,
    FlowyResult<Uint8List, FlowyError> result,
  ) {
    switch (ty) {
      case FolderNotification.DidUpdateMentionablePersons:
        result.fold(
          (payload) => _mentionablePersonsNotifier?.value = FlowyResult.success(
            MentionablePersonChangeSetPB.fromBuffer(payload),
          ),
          (error) =>
              _mentionablePersonsNotifier?.value = FlowyResult.failure(error),
        );
        break;
      case FolderNotification.DidReloadMentionablePersons:
        result.fold(
          (payload) =>
              _mentionablePersonsReloadedNotifier?.value = FlowyResult.success(
            GetMentionablePersonsResponsePB.fromBuffer(payload),
          ),
          (error) => _mentionablePersonsReloadedNotifier?.value =
              FlowyResult.failure(error),
        );
        break;
      default:
        break;
    }
  }

  Future<void> stop() async {
    _mentionablePersonsNotifier?.dispose();
    _mentionablePersonsNotifier = null;
    _mentionablePersonsReloadedNotifier?.dispose();
    _mentionablePersonsReloadedNotifier = null;
    await _listener?.stop();
  }
}
