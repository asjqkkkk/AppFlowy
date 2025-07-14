import 'package:appflowy/features/mension_person/data/models/invite.dart';

import 'package:appflowy/features/mension_person/data/models/person.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';

import 'package:appflowy_result/appflowy_result.dart';

import 'mention_repository.dart';

class RustMentionRepository extends MentionRepository {
  @override
  Future<FlowyResult<PersonWithAccess, FlowyError>> getPerson({
    required String workspaceId,
    required String documentId,
    required String personId,
  }) {
    // TODO: implement getPerson
    throw UnimplementedError();
  }

  @override
  Future<FlowyResult<List<Person>, FlowyError>> getPersons({
    required String workspaceId,
    required String query,
  }) async {
    final result = await ViewBackendService.getWorkspaceMentionablePersons();
    final formatedQuery = query.trim().toLowerCase();
    return result.fold(
      (r) {
        return FlowyResult.success(
          r.persons
              .map((e) => Person.fromProto(e))
              .where(
                (p) =>
                    p.name.toLowerCase().contains(formatedQuery) ||
                    p.email.toLowerCase().contains(formatedQuery),
              )
              .toList(),
        );
      },
      (error) {
        return FlowyResult.failure(error);
      },
    );
  }

  @override
  Future<FlowyResult<Person, FlowyError>> invitePerson({
    required String workspaceId,
    required InviteInfo info,
  }) {
    // TODO: implement invitePerson
    throw UnimplementedError();
  }
}
