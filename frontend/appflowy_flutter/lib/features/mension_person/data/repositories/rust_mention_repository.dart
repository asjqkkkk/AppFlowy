import 'package:appflowy/features/mension_person/data/models/invite.dart';

import 'package:appflowy/features/mension_person/data/models/person.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';

import 'package:appflowy_result/appflowy_result.dart';
import 'package:easy_localization/easy_localization.dart';

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
  Future<FlowyResult<Person, FlowyError>> invitePerson({
    required String workspaceId,
    required InviteInfo info,
  }) {
    // TODO: implement invitePerson
    throw UnimplementedError();
  }

  @override
  Future<FlowyResult<void, FlowyError>> mentionPerson({
    required String documentId,
    required String personId,
    required bool requireNotification,
    String? blockId,
  }) async {
    final viewResult = await ViewBackendService.getView(documentId);
    final view = viewResult.toNullable();
    if (view == null) {
      Log.error('mention person with null view:$documentId');
      return FlowyResult.failure(FlowyError());
    }
    final result = ViewBackendService.updatePageMention(
      viewId: documentId,
      viewName: view.nameOrDefault,
      personId: personId,
      requireNotification: requireNotification,
      blockId: blockId,
    );
    if (await result.isError() && requireNotification) {
      showToastNotification(
        message: LocaleKeys.document_mentionMenu_notifedToFailed.tr(),
        type: ToastificationType.error,
      );
    }
    return result;
  }
}
