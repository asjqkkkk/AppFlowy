import 'package:appflowy/features/mension_person/data/models/invite.dart';

import 'package:appflowy/features/mension_person/data/models/person.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';

import 'package:appflowy_result/appflowy_result.dart';

import 'mention_repository.dart';

class RustMentionRepository extends MentionRepository {

  @override
  Future<FlowyResult<List<Person>, FlowyError>> getWorkspacePersons({
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
  Future<FlowyResult<List<PersonWithAccess>, FlowyError>> getPagePersons({
    required String workspaceId,
    required String documentId,
  }) async {
    final result =
        await ViewBackendService.getPageMentionablePersons(documentId);
    return result.fold(
      (r) {
        return FlowyResult.success(
          r.persons
              .map(
                (e) => PersonWithAccess(
                  person: Person.fromProto(e.person),
                  access: e.canAccessPage,
                ),
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

  @override
  Future<void> mentionPerson({
    required String documentId,
    required String personId,
    required bool requireNotification,
    String? blockId,
  }) async {
     await ViewBackendService.updatePageMention(
      viewId: documentId,
      personId: personId,
      requireNotification: requireNotification,
      blockId: blockId,
    );
  }
}
