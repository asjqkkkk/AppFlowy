import 'dart:async';

import 'package:appflowy/core/notification/folder_notification.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/notification.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:flowy_infra/notifier.dart';
import 'package:flutter/foundation.dart';

typedef MentionablePersonsNotifyValue
    = FlowyResult<List<MentionablePersonPB>, FlowyError>;
typedef MentionablePersonNotifyValue
    = FlowyResult<MentionablePersonPB, FlowyError>;
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
  PublishNotifier<MentionablePersonNotifyValue>? _mentionablePersonNotifier =
      PublishNotifier();
  PublishNotifier<SharedUsersNotifyValue>? _sharedUsersNotifier =
      PublishNotifier();

  FolderNotificationListener? _listener;

  void start({
    ValueChanged<MentionablePersonsNotifyValue>? mentionablePersonsChanged,
    ValueChanged<MentionablePersonNotifyValue>? mentionablePersonChanged,
    ValueChanged<SharedUsersNotifyValue>? sharedUsersChanged,
  }) {
    if (mentionablePersonsChanged != null) {
      _mentionablePersonsNotifier
          ?.addPublishListener(mentionablePersonsChanged);
    }

    if (mentionablePersonChanged != null) {
      _mentionablePersonNotifier?.addPublishListener(mentionablePersonChanged);
    }
    if (sharedUsersChanged != null) {
      _sharedUsersNotifier?.addPublishListener(sharedUsersChanged);
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
      case FolderNotification.DidUpdateMentionablePerson:
        result.fold(
          (payload) => _mentionablePersonNotifier?.value =
              FlowyResult.success(MentionablePersonPB.fromBuffer(payload)),
          (error) =>
              _mentionablePersonNotifier?.value = FlowyResult.failure(error),
        );
        break;
      case FolderNotification.DidUpdateMentionablePersons:
        result.fold(
          (payload) => _mentionablePersonsNotifier?.value = FlowyResult.success(
            GetMentionablePersonsResponsePB.fromBuffer(payload).persons,
          ),
          (error) =>
              _mentionablePersonsNotifier?.value = FlowyResult.failure(error),
        );
        break;
      case FolderNotification.DidUpdateSharedUsers:
        result.fold(
          (payload) => _sharedUsersNotifier?.value = FlowyResult.success(
            RepeatedSharedUserPB.fromBuffer(payload).items,
          ),
          (error) => _sharedUsersNotifier?.value = FlowyResult.failure(error),
        );
      default:
        break;
    }
  }

  Future<void> stop() async {
    _mentionablePersonsNotifier?.dispose();
    _mentionablePersonNotifier?.dispose();
    _sharedUsersNotifier?.dispose();
    _mentionablePersonsNotifier = null;
    _mentionablePersonNotifier = null;
    _sharedUsersNotifier = null;
    await _listener?.stop();
  }
}
