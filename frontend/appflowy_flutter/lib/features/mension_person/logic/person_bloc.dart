import 'dart:typed_data';

import 'package:appflowy/core/notification/folder_notification.dart';
import 'package:appflowy/features/mension_person/data/repositories/mention_repository.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';
import 'package:appflowy/workspace/application/workspace/workspace_mentionable_listener.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/notification.pbenum.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'person_event.dart';
import 'person_state.dart';

export 'person_event.dart';
export 'person_state.dart';

class PersonBloc extends Bloc<PersonEvent, PersonState> {
  PersonBloc({
    required this.documentId,
    required this.workspaceId,
    this.initialSharedUserFromServer = false,
    required this.repository,
  })  : _workspaceListener =
            WorkspaceMentionableListener(workspaceId: workspaceId),
        super(PersonState.initial()) {
    _workspaceListener.start(
      mentionablePersonsChanged: onMentionablePersonsChanged,
      mentionablePersonsReloaded: onMentionablePersonsReloaded,
    );
    _folderNotificationListener = FolderNotificationListener(
      objectId: documentId,
      handler: _onNotification,
    );
    on<InitialEvent>(_onInitial);
    on<NotifyPersonEvent>(_onNotifyPersonEvent);
    on<UpdatePersonsEvent>(_onUpdatePersonsEvent);
    on<ReloadPersonsEvent>(_onReloadPersonsEvent);
    on<RemovePersonsEvent>(_onRemovePersonsEvent);
    on<UpdateAvailableEmailsEvent>(_onUpdateAvailableEmailsEvent);
  }

  final String documentId;
  final String workspaceId;
  final bool initialSharedUserFromServer;
  final MentionRepository repository;
  final WorkspaceMentionableListener _workspaceListener;
  late final FolderNotificationListener _folderNotificationListener;

  @override
  Future<void> close() async {
    await _workspaceListener.stop();
    await _folderNotificationListener.stop();
    return super.close();
  }

  Future<void> _onInitial(
    InitialEvent event,
    Emitter<PersonState> emit,
  ) async {
    final availableEmails = await _getFolderEventGetSharedUsers(
      isFetchFromCloud: initialSharedUserFromServer,
    );
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
      }, (e) {
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
      personId: event.person.uuid,
      ancestorId: event.ancestorId,
      requireNotification: true,
      blockId: event.blockId,
    );
    await result.fold((s) async {
      // Refresh the persons list after successful notification
      final personsResult = await repository.getWorkspacePersons(
        workspaceId: workspaceId,
        query: '',
      );

      final persons = personsResult.toNullable() ?? state.persons;
      if (!isClosed) {
        emit(
          state.copyWith(
            persons: persons,
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

  Future<void> _onUpdatePersonsEvent(
    UpdatePersonsEvent event,
    Emitter<PersonState> emit,
  ) async {
    // Upsert persons in the current state
    final List<MentionablePersonPB> currentPersons = List.of(state.persons);
    for (final person in event.persons) {
      final index = currentPersons.indexWhere((p) => p.uuid == person.uuid);
      if (index != -1) {
        currentPersons[index] = person;
      } else {
        currentPersons.add(person);
      }
    }
    final availableEmails = await _getFolderEventGetSharedUsers();
    emit(
      state.copyWith(
        persons: currentPersons,
        availableEmails: availableEmails,
      ),
    );
  }

  Future<void> _onReloadPersonsEvent(
    ReloadPersonsEvent event,
    Emitter<PersonState> emit,
  ) async {
    emit(state.copyWith(persons: event.persons));
  }

  Future<void> _onRemovePersonsEvent(
    RemovePersonsEvent event,
    Emitter<PersonState> emit,
  ) async {
    // Remove persons from the current state
    final List<MentionablePersonPB> currentPersons = List.of(state.persons);
    currentPersons.removeWhere((p) => event.personIds.contains(p.uuid));
    final availableEmails = await _getFolderEventGetSharedUsers();
    emit(
      state.copyWith(
        persons: currentPersons,
        availableEmails: availableEmails,
      ),
    );
  }

  Future<void> _onUpdateAvailableEmailsEvent(
    UpdateAvailableEmailsEvent event,
    Emitter<PersonState> emit,
  ) async {
    emit(state.copyWith(availableEmails: event.emails));
  }

  Future<List<String>> _getFolderEventGetSharedUsers({
    bool isFetchFromCloud = false,
  }) async {
    final documentUsersResult = await FolderEventGetSharedUsers(
      GetSharedUsersPayloadPB(
        viewId: documentId,
        isFetchFromCloud: isFetchFromCloud,
      ),
    ).send();

    final users = documentUsersResult.fold(
      (users) => users.items,
      (error) => <SharedUserPB>[],
    );
    return users.map((user) => user.email).toList();
  }

  void onMentionablePersonsChanged(MentionablePersonsNotifyValue v) {
    v.fold((v) {
      final updatedPersons = v.updated;
      final removedPersonIds = v.removed;
      if (!isClosed) {
        if (updatedPersons.isNotEmpty) {
          add(PersonEvent.updatePersons(updatedPersons));
        }
        if (removedPersonIds.isNotEmpty) {
          add(PersonEvent.removePersons(removedPersonIds));
        }
      }
    }, (e) {
      Log.error('Failed to notify mentionable persons: $e');
    });
  }

  void onMentionablePersonsReloaded(MentionablePersonsReloadedNotifyValue v) {
    v.fold((v) {
      final persons = v.persons;
      if (!isClosed) {
        add(PersonEvent.reloadPersons(persons));
      }
    }, (e) {
      Log.error('Failed to reload mentionable persons: $e');
    });
  }

  void _onNotification(
    FolderNotification notification,
    FlowyResult<Uint8List, FlowyError> result,
  ) {
    if (notification == FolderNotification.DidUpdateSharedUsers) {
      result.fold(
        (payload) {
          final sharedUsers = RepeatedSharedUserPB.fromBuffer(payload).items;
          final availableEmails = sharedUsers.map((e) => e.email).toList();
          if (!isClosed) {
            add(PersonEvent.updateAvailableEmails(availableEmails));
          }
        },
        (error) => null,
      );
    }
  }

  static List<BlocListener> buildBlocToastListener() {
    return [
      BlocListener<PersonBloc, PersonState>(
        listener: (context, state) {
          final person = state.mentionedErrorPerson;
          if (person != null) {
            showToastNotification(
              message: LocaleKeys.document_mentionMenu_notifedToFailed.tr(),
              type: ToastificationType.error,
            );
          }
        },
        listenWhen: (previous, current) =>
            previous.mentionedErrorPerson != current.mentionedErrorPerson,
      ),
      BlocListener<PersonBloc, PersonState>(
        listener: (context, state) {
          final person = state.mentionedSucceedPerson;
          if (person != null) {
            showToastNotification(
              message: LocaleKeys.document_mentionMenu_notifedTo
                  .tr(args: [person.name]),
            );
          }
        },
        listenWhen: (previous, current) =>
            previous.mentionedSucceedPerson != current.mentionedSucceedPerson,
      ),
    ];
  }
}
