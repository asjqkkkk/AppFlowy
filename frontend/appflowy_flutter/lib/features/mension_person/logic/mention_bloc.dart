import 'package:appflowy/features/mension_person/data/cache/person_list_cache.dart';
import 'package:appflowy/features/mension_person/data/models/mention_menu_item.dart';
import 'package:appflowy/features/mension_person/data/models/person.dart';
import 'package:appflowy/features/mension_person/data/repositories/mention_repository.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'mention_event.dart';
export 'mention_event.dart';
import 'mention_state.dart';
export 'mention_state.dart';

class MentionBloc extends Bloc<MentionEvent, MentionState> {
  MentionBloc({
    required this.repository,
    required this.workspaceId,
    required this.query,
    required this.sendNotification,
    required this.personListCache,
  }) : super(
          MentionState(
            sendNotification: sendNotification,
            itemMap: MentionItemMap.empty(),
          ),
        ) {
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
    on<UpdateItemMap>(_onUpdateItemMap);
    on<MentionPerson>(_onMentionPerson);
    on<ExecuteItem>(_onItemExecuted);
  }
  final MentionRepository repository;
  final String workspaceId;
  final String query;
  final bool sendNotification;
  final PersonListMemoryCache personListCache;

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
    final query = event.text;
    List<MentionMenuItem> dateAndReminders =
        List.of(dateReminderMentionMenuItems);
    if (query.isNotEmpty) {
      dateAndReminders = dateAndReminders
          .where((e) => e.id.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    final newItemMap = state.itemMap
        .clearItems(MentionMenuType.dateAndReminder)
        .addItems(dateAndReminders);

    emit(
      state.copyWith(
        query: query,
        selectedId: newItemMap.items.first.id,
        itemMap: newItemMap,
      ),
    );
    add(MentionEvent.getPersons(workspaceId: workspaceId));
    add(MentionEvent.updateViews(state.views));
  }

  Future<void> _onGetPersons(
    GetPersons event,
    Emitter<MentionState> emit,
  ) async {
    List<Person> cachedPersons = personListCache.getPersons(workspaceId) ?? [];

    if (state.query.isNotEmpty) {
      final formatedQuery = state.query.toLowerCase();
      cachedPersons = cachedPersons
          .where(
            (p) =>
                p.name.toLowerCase().contains(formatedQuery) ||
                p.email.toLowerCase().contains(formatedQuery),
          )
          .toList();

      /// TODO : Don't forget to add [AddPersonMentionMenuItem] after backend supports it
      // AddPersonMentionMenuItem addItem = AddPersonMentionMenuItem(query: query);
    }

    List<MentionMenuItem> personItems =
        cachedPersons.map((p) => PersonMentionMenuItem(person: p)).toList();
    if (personItems.length > 4) {
      if (!state.showMorePersons) {
        personItems = personItems.sublist(0, 4);
        personItems.add(
          MoreResultMentionMenuItem(
            id: MoreResultMentionMenuItem.showMorePersonsId,
            type: MentionMenuType.person,
          ),
        );
      }
    }
    final newItemMap =
        state.itemMap.clearItems(MentionMenuType.person).addItems(personItems);
    emit(state.copyWith(persons: cachedPersons, itemMap: newItemMap));
    final persons = (await repository.getWorkspacePersons(
          workspaceId: event.workspaceId,
          query: state.query,
        ))
            .toNullable() ??
        [];

    if ((persons.isNotEmpty) && state.query.isEmpty) {
      personItems =
          persons.map((p) => PersonMentionMenuItem(person: p)).toList();
      final newItemMap = state.itemMap
          .clearItems(MentionMenuType.person)
          .addItems(personItems);
      emit(
        state.copyWith(
          persons: persons,
          itemMap: newItemMap,
          selectedId: newItemMap.items.first.id,
        ),
      );
      personListCache.updatePersonList(workspaceId, persons);
    }
  }

  Future<void> _onUpdatePersonList(
    UpdatePersonList event,
    Emitter<MentionState> emit,
  ) async {
    List<MentionMenuItem> personItems =
        event.persons.map((p) => PersonMentionMenuItem(person: p)).toList();
    if (personItems.length > 4) {
      if (!state.showMorePersons) {
        personItems = personItems.sublist(0, 4);
        personItems.add(
          MoreResultMentionMenuItem(
            id: MoreResultMentionMenuItem.showMorePersonsId,
            type: MentionMenuType.person,
          ),
        );
      }
    }
    final newItemMap =
        state.itemMap.clearItems(MentionMenuType.person).addItems(personItems);
    emit(
      state.copyWith(
        persons: event.persons,
        itemMap: newItemMap,
        selectedId: newItemMap.items.first.id,
      ),
    );
  }

  Future<void> _onUpdateViews(
    UpdateViews event,
    Emitter<MentionState> emit,
  ) async {
    final List<MentionMenuItem> items = [];
    final query = state.query;
    final views = event.views
        .where(
          (e) => e.nameOrDefault.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    if (views.length > 4) {
      if (!state.showMorePage) {
        items.addAll(
          views.sublist(0, 4).map((e) => PageMentionMenuItem(view: e)),
        );
        items.add(
          MoreResultMentionMenuItem(
            id: MoreResultMentionMenuItem.showMorePagesId,
            type: MentionMenuType.page,
          ),
        );
      } else {
        items.addAll(views.map((e) => PageMentionMenuItem(view: e)));
      }
    } else {
      items.addAll(views.map((e) => PageMentionMenuItem(view: e)));
    }
    if (query.isNotEmpty) {
      items.add(AddViewMenuItem(query: query));
    }
    final newItems =
        state.itemMap.clearItems(MentionMenuType.page).addItems(items);
    emit(
      state.copyWith(
        views: event.views,
        filterViews: views,
        selectedId: newItems.items.first.id,
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

  Future<void> _onUpdateItemMap(
    UpdateItemMap event,
    Emitter<MentionState> emit,
  ) async {
    emit(
      state.copyWith(
        itemMap: event.map,
        selectedId: event.map.items.first.id,
      ),
    );
  }

  Future<void> _onMentionPerson(
    MentionPerson event,
    Emitter<MentionState> emit,
  ) async {
    await repository.mentionPerson(
      documentId: event.documentId,
      blockId: event.blockId,
      personId: event.personId,
      requireNotification: state.sendNotification,
    );
  }

  Future<void> _onItemExecuted(
    ExecuteItem event,
    Emitter<MentionState> emit,
  ) async {
    emit(state.copyWith(executedItem: event.item));
  }
}
