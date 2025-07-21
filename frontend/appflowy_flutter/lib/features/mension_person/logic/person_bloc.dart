import 'package:appflowy/features/mension_person/data/cache/person_list_cache.dart';
import 'package:appflowy/features/mension_person/data/models/person.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'person_event.dart';
export 'person_event.dart';
import 'person_state.dart';
export 'person_state.dart';

class PersonBloc extends Bloc<PersonEvent, PersonState> {
  PersonBloc({
    required this.documentId,
    required this.nodeId,
    required this.personId,
    required this.workspaceId,
    required this.personListCache,
  }) : super(PersonState.initial()) {
    on<InitialEvent>(_onInitial);
    on<UpdatePersonEvent>(_onUpdatePerson);
    on<UpdateStatusEvent>(_onUpdateStatusEvent);
    on<NotifyPersonEvent>(_onNotifyPersonEvent);
  }
  final String documentId;
  final String nodeId;
  final String personId;
  final String workspaceId;
  final PersonListWithAccessMemoryCache personListCache;

  @override
  Future<void> close() async {
    personListCache.removePersonListWithAcessFetchedCallback(
      documentId,
      onPersonList,
    );
    await super.close();
  }

  Future<void> _onInitial(
    InitialEvent event,
    Emitter<PersonState> emit,
  ) async {
    personListCache.onPersonListWithAcessFetched(documentId, onPersonList);
  }

  Future<void> _onUpdatePerson(
    UpdatePersonEvent event,
    Emitter<PersonState> emit,
  ) async {
    emit(
      state.copyWith(personWithAccess: event.person, status: PersonStatus.idle),
    );
  }

  Future<void> _onUpdateStatusEvent(
    UpdateStatusEvent event,
    Emitter<PersonState> emit,
  ) async {
    emit(
      state.copyWith(
        status: event.status,
        getPersonFailedMesssage: event.errorMessage,
      ),
    );
  }

  Future<void> _onNotifyPersonEvent(
    NotifyPersonEvent event,
    Emitter<PersonState> emit,
  ) async {
    await ViewBackendService.updatePageMention(
      viewId: documentId,
      personId: personId,
      requireNotification: true,
      blockId: nodeId,
    );
  }

  Future<void> onPersonList(PersonListWithAccessAndResult result) async {
    if (isClosed) return;
    if (!result.succeed) {
      add(PersonEvent.updateStatusEvent(status: PersonStatus.error));
      return;
    }
    final localPerson =
        result.persons.where((p) => p.person.id == personId).firstOrNull;
    if (localPerson != null) {
      add(PersonEvent.updatePerson(localPerson));
    } else {
      add(
        PersonEvent.updatePerson(
          PersonWithAccess(
            person: Person.empty().copyWith(deleted: true),
            access: false,
          ),
        ),
      );
    }
  }
}
