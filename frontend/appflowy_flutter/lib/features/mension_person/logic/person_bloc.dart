import 'package:appflowy/features/mension_person/data/cache/person_list_cache.dart';
import 'package:appflowy/features/mension_person/data/models/person.dart';
import 'package:appflowy/features/mension_person/data/repositories/mention_repository.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';
import 'package:appflowy/workspace/application/workspace/workspace_mentionable_listener.dart';
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
  })  : _listener = WorkspaceMentionableListener(workspaceId: workspaceId),
        super(PersonState.initial()) {
    on<InitialEvent>(_onInitial);
    on<NotifyPersonEvent>(_onNotifyPersonEvent);
    on<UpdatePersonEvent>(_onUpdatePersonEvent);
    on<UpdatePersonsEvent>(_onUpdatePersonsEvent);
    _listener.start(
      mentionablePersonChanged: onMentionablePersonChanged,
      mentionablePersonsChanged: onMentionablePersonsChanged,
    );
  }

  final String documentId;
  final String workspaceId;
  final PersonListMemoryCache personListCache;
  final MentionRepository repository;
  final WorkspaceMentionableListener _listener;

  @override
  Future<void> close() async {
    await _listener.stop();
    return super.close();
  }

  Future<void> _onInitial(
    InitialEvent event,
    Emitter<PersonState> emit,
  ) async {
    final localPersons = personListCache.getPersons(workspaceId) ?? [];
    if (localPersons.isNotEmpty) {
      emit(state.copyWith(persons: localPersons, status: PersonStatus.idle));
    }

    final availableEmails = await _getFolderEventGetSharedUsers();
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

  Future<void> _onUpdatePersonEvent(
    UpdatePersonEvent event,
    Emitter<PersonState> emit,
  ) async {
    personListCache.updatePerson(workspaceId, event.person);
    final availableEmails = await _getFolderEventGetSharedUsers();
    final newPersons = personListCache.getPersons(workspaceId);
    emit(
      state.copyWith(persons: newPersons, availableEmails: availableEmails),
    );
  }

  Future<void> _onUpdatePersonsEvent(
    UpdatePersonsEvent event,
    Emitter<PersonState> emit,
  ) async {
    personListCache.updatePersonList(workspaceId, event.persons);
    final availableEmails = await _getFolderEventGetSharedUsers();
    emit(
      state.copyWith(persons: event.persons, availableEmails: availableEmails),
    );
  }

  Future<List<String>> _getFolderEventGetSharedUsers() async {
    final documentUsersResult = await FolderEventGetSharedUsers(
      GetSharedUsersPayloadPB(viewId: documentId, isFetchFromCloud: false),
    ).send();

    final users = documentUsersResult.fold(
      (users) => users.items,
      (error) => <SharedUserPB>[],
    );
    return users.map((user) => user.email).toList();
  }

  void onMentionablePersonsChanged(MentionablePersonsNotifyValue v) {
    v.fold((v) {
      final persons = v.map((e) => Person.fromProto(e)).toList();
      if (!isClosed) add(PersonEvent.updatePersons(persons));
    }, (e) {
      Log.error('Failed to notify mentionable persons: $e');
    });
  }

  void onMentionablePersonChanged(MentionablePersonNotifyValue v) {
    v.fold((v) {
      if (!isClosed) add(PersonEvent.updatePerson(Person.fromProto(v)));
    }, (e) {
      Log.error('Failed to notify mentionable person: $e');
    });
  }
}
