import 'package:appflowy/features/mension_person/data/models/models.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';

abstract class MentionRepository {
  /// Gets the list of persons
  Future<FlowyResult<List<Person>, FlowyError>> getWorkspacePersons({
    required String workspaceId,
    required String query,
  });

  /// Gets the list of persons
  Future<FlowyResult<List<PersonWithAccess>, FlowyError>> getPagePersons({
    required String workspaceId,
    required String documentId,
  });

  Future<FlowyResult<PersonWithAccess, FlowyError>> getPerson({
    required String workspaceId,
    required String documentId,
    required String personId,
  });

  /// Invite a person
  Future<FlowyResult<Person, FlowyError>> invitePerson({
    required String workspaceId,
    required InviteInfo info,
  });
}
