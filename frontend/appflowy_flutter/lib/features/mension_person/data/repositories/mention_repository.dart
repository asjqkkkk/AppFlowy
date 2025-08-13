import 'package:appflowy/features/mension_person/data/models/models.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';

abstract class MentionRepository {
  /// Gets the list of persons
  Future<FlowyResult<List<MentionablePersonPB>, FlowyError>>
      getWorkspacePersons({
    required String workspaceId,
    required String query,
  });

  /// Invite a person
  Future<FlowyResult<MentionablePersonPB, FlowyError>> invitePerson({
    required String workspaceId,
    required InviteInfo info,
  });

  /// mention a person
  Future<FlowyResult<void, FlowyError>> mentionPerson({
    required String documentId,
    required String personId,
    required String ancestorId,
    required bool requireNotification,
    String? blockId,
  });
}
