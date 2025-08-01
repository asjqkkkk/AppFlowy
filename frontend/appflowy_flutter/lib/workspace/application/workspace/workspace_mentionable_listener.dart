import 'dart:async';
import 'dart:typed_data';

import 'package:appflowy/core/notification/folder_notification.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/notification.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:flowy_infra/notifier.dart';

typedef MentionablePersonsNotifyValue
    = FlowyResult<List<MentionablePersonPB>, FlowyError>;
typedef MentionablePersonNotifyValue
    = FlowyResult<MentionablePersonPB, FlowyError>;

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

  FolderNotificationListener? _listener;

  void start({
    void Function(MentionablePersonsNotifyValue)? mentionablePersonsChanged,
    void Function(MentionablePersonNotifyValue)? mentionablePersonChanged,
  }) {
    if (mentionablePersonsChanged != null) {
      _mentionablePersonsNotifier
          ?.addPublishListener(mentionablePersonsChanged);
    }

    if (mentionablePersonChanged != null) {
      _mentionablePersonNotifier?.addPublishListener(mentionablePersonChanged);
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
      default:
        break;
    }
  }

  Future<void> stop() async {
    await _listener?.stop();
    _mentionablePersonsNotifier?.dispose();
    _mentionablePersonsNotifier = null;
    _mentionablePersonNotifier?.dispose();
    _mentionablePersonNotifier = null;
  }
}
