import 'package:appflowy/features/mension_person/data/cache/person_list_cache.dart';
import 'package:appflowy/features/mension_person/data/repositories/mention_repository.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'person_event.dart';
export 'person_event.dart';
import 'person_state.dart';
export 'person_state.dart';

class PersonBloc extends Bloc<PersonEvent, PersonState> {
  PersonBloc({
    required this.documentId,
    required this.workspaceId,
    required this.personListCache,
    required this.repository,
  }) : super(PersonState.initial()) {
    on<InitialEvent>(_onInitial);
    on<NotifyPersonEvent>(_onNotifyPersonEvent);
  }
  final String documentId;
  final String workspaceId;
  final PersonListMemoryCache personListCache;
  final MentionRepository repository;

  Future<void> _onInitial(
    InitialEvent event,
    Emitter<PersonState> emit,
  ) async {
    final localPersons = personListCache.getPersons(workspaceId) ?? [];
    if (localPersons.isNotEmpty) {
      emit(state.copyWith(persons: localPersons, status: PersonStatus.idle));
    }
    final documentUsersResult = await FolderEventGetSharedUsers(
      GetSharedUsersPayloadPB(viewId: documentId),
    ).send();

    final users = documentUsersResult.fold(
      (users) => users.items,
      (error) => <SharedUserPB>[],
    );
    final availableEmails = users.map((user) => user.email).toList();

    final personsResult = await repository.getWorkspacePersons(
      workspaceId: workspaceId,
      query: '',
    );
    if (!isClosed) {
      personsResult.fold((s) {
        emit(
          state.copyWith(
            persons: s,
            availableEmails: availableEmails,
            status: PersonStatus.idle,
          ),
        );
        personListCache.updatePersonList(workspaceId, s);
      }, (e) {
        Log.error('Failed to fetch persons: $e');
        emit(
          state.copyWith(
            status: PersonStatus.error,
            availableEmails: availableEmails,
          ),
        );
      });
    }
  }

  Future<void> _onNotifyPersonEvent(
    NotifyPersonEvent event,
    Emitter<PersonState> emit,
  ) async {
    final viewResult = await ViewBackendService.getView(documentId);
    final view = viewResult.toNullable();
    if (view == null) {
      Log.error('mention person with null view:$documentId');
      return;
    }
    final result = await ViewBackendService.updatePageMention(
      viewId: documentId,
      viewName: view.nameOrDefault,
      personId: event.person.id,
      requireNotification: true,
      blockId: event.blockId,
    );
    result.fold((s) {
      personListCache.movePersonToTop(workspaceId, event.person.id);
      if (!isClosed) {
        emit(
          state.copyWith(
            mentionedSucceedPerson: PersonWithNotifyTimes(
              person: event.person,
              notifyTimes: (state.mentionedSucceedPerson?.notifyTimes ?? 0) + 1,
            ),
          ),
        );
      }
    }, (e) {
      if (!isClosed) {
        emit(
          state.copyWith(
            mentionedErrorPerson: PersonWithNotifyTimes(
              person: event.person,
              notifyTimes: (state.mentionedErrorPerson?.notifyTimes ?? 0) + 1,
            ),
          ),
        );
      }
      Log.error('Failed to notify person: $e');
    });
  }
}
