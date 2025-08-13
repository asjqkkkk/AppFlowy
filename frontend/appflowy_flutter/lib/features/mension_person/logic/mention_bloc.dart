import 'package:appflowy/features/mension_person/data/models/mention_menu_item.dart';
import 'package:appflowy/features/mension_person/data/repositories/mention_repository.dart';
import 'package:appflowy/workspace/application/recent/cached_recent_service.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy/workspace/application/workspace/workspace_mentionable_listener.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'mention_event.dart';
import 'mention_state.dart';

export 'mention_event.dart';
export 'mention_state.dart';

class MentionBloc extends Bloc<MentionEvent, MentionState> {
  MentionBloc({
    required this.repository,
    required this.workspaceId,
    required this.query,
    required this.sendNotification,
  })  : _workspaceListener =
            WorkspaceMentionableListener(workspaceId: workspaceId),
        super(
          MentionState(
            sendNotification: sendNotification,
            itemMap: MentionItemMap.empty(),
          ),
        ) {
    _workspaceListener.start(
      mentionablePersonsReloaded: _onMentionablePersonsReloaded,
      mentionablePersonsChanged: _onMentionablePersonsChanged,
    );
    on<Initial>(_onInitial);
    on<Query>(_onQuery);
    on<GetPersons>(_onGetPersons);
    on<UpdatePersonList>(_onUpdatePersonList);
    on<UpdateViews>(_onUpdateViews);
    on<ShowMorePersons>(_onShowMorePersons);
    on<ShowMorePages>(_onShowMorePages);
    on<ToggleSendNotification>(_onToggleSendNotification);
    on<AddVisibleItem>(_onAddVisibleItem);
    on<RemoveVisibleItem>(_onRemoveVisibleItem);
    on<SelectItem>(_onSelectItem);
    on<MentionPerson>(_onMentionPerson);
    on<ExecuteItem>(_onItemExecuted);
    on<ReloadPersonsEvent>(_onReloadPersonsEvent);
  }
  final MentionRepository repository;
  final String workspaceId;
  final String query;
  final bool sendNotification;
  final WorkspaceMentionableListener _workspaceListener;

  @override
  Future<void> close() async {
    await _workspaceListener.stop();
    return super.close();
  }

  Future<void> _onInitial(
    Initial event,
    Emitter<MentionState> emit,
  ) async {
    emit(state.copyWith(showMorePersons: false, showMorePage: false));
    if (query.isNotEmpty) {
      add(MentionEvent.query(query));
    } else {
      add(MentionEvent.getPersons(workspaceId: workspaceId));
    }
  }

  Future<void> _onQuery(
    Query event,
    Emitter<MentionState> emit,
  ) async {
    final query = event.text,
        dateAndReminderItems = _getDateAndReminderItems(query),
        personItems = _getPersonItems(
          query,
          state.persons,
        );
    List<ViewPB> views = [];
    if (query.isEmpty) {
      views = (await readRecentViews()).map((e) => e.item).toList();
    } else {
      views = await readAllViews();
    }
    final viewItems = _getPageItems(query, views);
    final itemMap = state.itemMap
        .clearItems(MentionMenuType.values)
        .addItems([...dateAndReminderItems, ...personItems, ...viewItems]);

    emit(
      state.copyWith(
        query: query,
        selectedId: itemMap.items.first.id,
        itemMap: itemMap,
        filterViews: _filterViews(query, state.views),
      ),
    );
  }

  Future<void> _onGetPersons(
    GetPersons event,
    Emitter<MentionState> emit,
  ) async {
    await refreshPersonList(emit);
  }

  Future<void> refreshPersonList(Emitter<MentionState> emit) async {
    final persons = (await repository.getWorkspacePersons(
          workspaceId: workspaceId,
          query: state.query,
        ))
            .toNullable() ??
        [];

    if (persons.isNotEmpty) {
      final newPersonItems = _getPersonItems(state.query, persons);
      final newItemMap = state.itemMap
          .clearItems([MentionMenuType.person]).addItems(newPersonItems);
      emit(
        state.copyWith(
          persons: persons,
          itemMap: newItemMap,
          selectedId: newItemMap.items.first.id,
        ),
      );
    }
  }

  Future<void> _onUpdatePersonList(
    UpdatePersonList event,
    Emitter<MentionState> emit,
  ) async {
    final List<MentionMenuItem> personItems =
        _getPersonItems(state.query, event.persons);
    final newItemMap = state.itemMap
        .clearItems([MentionMenuType.person]).addItems(personItems);
    emit(
      state.copyWith(
        persons: event.persons,
        itemMap: newItemMap,
        selectedId: state.showMorePersons
            ? state.selectedId
            : newItemMap.items.first.id,
      ),
    );
  }

  Future<void> _onUpdateViews(
    UpdateViews event,
    Emitter<MentionState> emit,
  ) async {
    final List<MentionMenuItem> items = _getPageItems(state.query, event.views);
    final query = state.query;
    final newItems =
        state.itemMap.clearItems([MentionMenuType.page]).addItems(items);
    emit(
      state.copyWith(
        views: event.views,
        filterViews: _filterViews(query, event.views),
        selectedId:
            state.showMorePage ? state.selectedId : newItems.items.first.id,
        itemMap: newItems,
      ),
    );
  }

  Future<void> _onShowMorePersons(
    ShowMorePersons event,
    Emitter<MentionState> emit,
  ) async {
    emit(state.copyWith(showMorePersons: true, selectedId: event.lastId));
    add(MentionEvent.updatePersonList(state.persons));
  }

  Future<void> _onShowMorePages(
    ShowMorePages event,
    Emitter<MentionState> emit,
  ) async {
    emit(state.copyWith(showMorePage: true, selectedId: event.lastId));
    add(MentionEvent.updateViews(state.views));
    // _showMorePages = true;
  }

  Future<void> _onToggleSendNotification(
    ToggleSendNotification event,
    Emitter<MentionState> emit,
  ) async {
    final value = !state.sendNotification;
    emit(state.copyWith(sendNotification: value));
  }

  Future<void> _onAddVisibleItem(
    AddVisibleItem event,
    Emitter<MentionState> emit,
  ) async {
    final set = Set.of(state.visibleItems);
    set.add(event.id);
    emit(state.copyWith(visibleItems: set));
  }

  Future<void> _onRemoveVisibleItem(
    RemoveVisibleItem event,
    Emitter<MentionState> emit,
  ) async {
    final set = Set.of(state.visibleItems);
    set.remove(event.id);
    emit(state.copyWith(visibleItems: set));
  }

  Future<void> _onSelectItem(
    SelectItem event,
    Emitter<MentionState> emit,
  ) async {
    emit(state.copyWith(selectedId: event.id));
  }

  Future<void> _onMentionPerson(
    MentionPerson event,
    Emitter<MentionState> emit,
  ) async {
    final result = await repository.mentionPerson(
      documentId: event.documentId,
      blockId: event.blockId,
      personId: event.personId,
      ancestorId: event.ancestorId,
      requireNotification: state.sendNotification,
    );
    result.fold(
      (s) {},
      (e) {
        Log.error('Failed to mention person: ${e.msg}');
      },
    );
  }

  Future<void> _onItemExecuted(
    ExecuteItem event,
    Emitter<MentionState> emit,
  ) async {
    emit(state.copyWith(executedItem: event.item));
  }

  Future<void> _onReloadPersonsEvent(
    ReloadPersonsEvent event,
    Emitter<MentionState> emit,
  ) async {
    final List<MentionMenuItem> personItems =
        _getPersonItems(state.query, event.persons);
    final newItemMap = state.itemMap
        .clearItems([MentionMenuType.person]).addItems(personItems);
    final oldSelectedId = state.selectedId;
    final selectedItem =
        state.itemMap.items.where((e) => e.id == oldSelectedId).firstOrNull;
    String selectedId = oldSelectedId;

    if (selectedItem?.type == MentionMenuType.person) {
      final selectedIndex =
          event.persons.indexWhere((e) => e.uuid == selectedId);
      if (selectedItem is PersonMentionMenuItem && selectedIndex < 0) {
        if (personItems.isNotEmpty) {
          selectedId = personItems.first.id;
        } else {
          selectedId = newItemMap.items.first.id;
        }
      }
    }
    emit(
      state.copyWith(
        persons: event.persons,
        itemMap: newItemMap,
        selectedId: selectedId,
      ),
    );
  }

  List<MentionMenuItem> _getPersonItems(
    String query,
    List<MentionablePersonPB> persons,
  ) {
    final List<MentionMenuItem> personItems = [];
    personItems.addAll(persons.map((e) => PersonMentionMenuItem(person: e)));
    final formatQuery = query.toLowerCase();
    if (formatQuery.isNotEmpty) {
      personItems.clear();
      personItems.addAll(
        persons
            .where(
              (e) =>
                  e.name.toLowerCase().contains(formatQuery) ||
                  e.email.toLowerCase().contains(formatQuery),
            )
            .map((e) => PersonMentionMenuItem(person: e)),
      );
    }
    if (personItems.length > 4 && !state.showMorePersons) {
      final newList = personItems.sublist(0, 4);
      personItems.clear();
      personItems.addAll(newList);
      personItems.add(
        MoreResultMentionMenuItem(
          id: MoreResultMentionMenuItem.showMorePersonsId,
          type: MentionMenuType.person,
        ),
      );
    }

    /// TODO : Don't forget to add [AddPersonMentionMenuItem] after backend supports it
    // if (query.isNotEmpty) {
    //   personItems.add(AddPersonMentionMenuItem(query: query));
    // }
    return personItems;
  }

  List<MentionMenuItem> _getPageItems(String query, List<ViewPB> views) {
    final List<MentionMenuItem> pageItems = [];
    pageItems.addAll(views.map((e) => PageMentionMenuItem(view: e)));
    final formatQuery = query.toLowerCase();
    if (formatQuery.isNotEmpty) {
      pageItems.clear();
      pageItems.addAll(
        _filterViews(query, views).map((e) => PageMentionMenuItem(view: e)),
      );
    }
    if (pageItems.length > 4 && !state.showMorePage) {
      final newItems = pageItems.sublist(0, 4);
      pageItems.clear();
      pageItems.addAll(newItems);
      pageItems.add(
        MoreResultMentionMenuItem(
          id: MoreResultMentionMenuItem.showMorePagesId,
          type: MentionMenuType.page,
        ),
      );
    }
    if (query.isNotEmpty) {
      pageItems.add(AddViewMenuItem(query: query));
    }
    return pageItems;
  }

  List<MentionMenuItem> _getDateAndReminderItems(String query) {
    final formatQuery = query.toLowerCase();
    if (formatQuery.isEmpty) {
      return dateReminderMentionMenuItems;
    }
    return dateReminderMentionMenuItems
        .where((e) => e.id.toLowerCase().contains(formatQuery))
        .toList();
  }

  List<ViewPB> _filterViews(String query, List<ViewPB> views) {
    final formatQuery = query.toLowerCase();
    if (formatQuery.isEmpty) return views;
    return views
        .where((e) => e.nameOrDefault.toLowerCase().contains(formatQuery))
        .toList();
  }

  void _onMentionablePersonsReloaded(MentionablePersonsReloadedNotifyValue v) {
    v.fold((v) {
      final persons = v.persons;
      if (!isClosed) {
        add(MentionEvent.reloadPersons(persons));
      }
    }, (e) {
      Log.error('Failed to reload mentionable persons: $e');
    });
  }

  void _onMentionablePersonsChanged(MentionablePersonsNotifyValue v) {
    v.fold((v) {
      final updatedPersons = v.updated;
      final removedPersonIds = v.removed.toSet();
      if (isClosed) return;
      final List<MentionablePersonPB> currentPersons = List.of(state.persons);
      if (updatedPersons.isNotEmpty) {
        for (final person in updatedPersons) {
          final index = currentPersons.indexWhere((p) => p.uuid == person.uuid);
          if (index != -1) {
            currentPersons[index] = person;
          } else {
            currentPersons.add(person);
          }
        }
      }
      if (removedPersonIds.isNotEmpty) {
        currentPersons.removeWhere((e) => removedPersonIds.contains(e.uuid));
      }
      add(MentionEvent.reloadPersons(currentPersons));
    }, (e) {
      Log.error('Failed to notify mentionable persons: $e');
    });
  }
}
