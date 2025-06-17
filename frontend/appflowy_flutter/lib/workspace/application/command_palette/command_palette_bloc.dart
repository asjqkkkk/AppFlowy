import 'dart:async';

import 'package:appflowy/plugins/trash/application/trash_listener.dart';
import 'package:appflowy/plugins/trash/application/trash_service.dart';
import 'package:appflowy/util/debounce.dart';
import 'package:appflowy/workspace/application/command_palette/command_palette_event.dart';
import 'package:appflowy/workspace/application/command_palette/command_palette_state.dart';
import 'package:appflowy/workspace/application/command_palette/search_service.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart'
    hide AFRolePB;
import 'package:appflowy_backend/protobuf/flowy-search/result.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

export 'command_palette_event.dart';
export 'command_palette_state.dart';

class CommandPaletteBloc
    extends Bloc<CommandPaletteEvent, CommandPaletteState> {
  CommandPaletteBloc() : super(CommandPaletteState.initial()) {
    on<CommandPaletteSearchChangedEvent>(_onSearchChanged);
    on<CommandPalettePerformSearchEvent>(_onPerformSearch);
    on<CommandPaletteNewSearchStreamEvent>(_onNewSearchStream);
    on<CommandPaletteResultsChangedEvent>(_onResultsChanged);
    on<CommandPaletteTrashChangedEvent>(_onTrashChanged);
    on<CommandPaletteWorkspaceChangedEvent>(_onWorkspaceChanged);
    on<CommandPaletteClearSearchEvent>(_onClearSearch);
    on<CommandPaletteGoingToAskAIEvent>(_onGoingToAskAI);
    on<CommandPaletteAskedAIEvent>(_onAskedAI);
    on<CommandPaletteRefreshCachedViewsEvent>(_onRefreshCachedViews);
    on<CommandPaletteUpdateCachedViewsEvent>(_onUpdateCachedViews);

    _initTrash();
    _refreshCachedViews();
  }

  final _searchDebounce = Debounce(
    duration: const Duration(milliseconds: 300),
  );
  final TrashService _trashService = TrashService();
  final TrashListener _trashListener = TrashListener();
  String? _activeQuery;
  AFRolePB? _myRole;

  @override
  Future<void> close() {
    _trashListener.close();
    _searchDebounce.dispose();
    state.searchResponseStream?.dispose();
    return super.close();
  }

  Future<void> _initTrash() async {
    _trashListener.start(
      trashUpdated: (trashOrFailed) => add(
        CommandPaletteEvent.trashChanged(
          trash: trashOrFailed.toNullable(),
        ),
      ),
    );

    final trashOrFailure = await _trashService.readTrash();
    trashOrFailure.fold(
      (trash) {
        if (!isClosed) {
          add(CommandPaletteEvent.trashChanged(trash: trash.items));
        }
      },
      (error) => debugPrint('Failed to load trash: $error'),
    );
  }

  Future<void> _refreshCachedViews() async {
    /// Sometimes non-existent views appear in the search results
    /// and the icon data for the search results is empty
    /// Fetching all views can temporarily resolve these issues
    final repeatedViewPB =
        (await ViewBackendService.getAllViews()).toNullable();
    if (repeatedViewPB == null || isClosed) return;
    add(CommandPaletteEvent.updateCachedViews(views: repeatedViewPB.items));
  }

  FutureOr<void> _onRefreshCachedViews(
    CommandPaletteRefreshCachedViewsEvent event,
    Emitter<CommandPaletteState> emit,
  ) {
    _refreshCachedViews();
  }

  FutureOr<void> _onUpdateCachedViews(
    CommandPaletteUpdateCachedViewsEvent event,
    Emitter<CommandPaletteState> emit,
  ) {
    final cachedViews = <String, ViewPB>{};
    for (final view in event.views) {
      cachedViews[view.id] = view;
    }
    emit(state.copyWith(cachedViews: cachedViews));
  }

  FutureOr<void> _onSearchChanged(
    CommandPaletteSearchChangedEvent event,
    Emitter<CommandPaletteState> emit,
  ) {
    _searchDebounce.call(
      () {
        if (!isClosed) {
          _myRole = event.role;
          add(CommandPaletteEvent.performSearch(search: event.search));
        }
      },
    );
  }

  FutureOr<void> _onPerformSearch(
    CommandPalettePerformSearchEvent event,
    Emitter<CommandPaletteState> emit,
  ) async {
    if (event.search.isEmpty) {
      emit(
        state.copyWith(
          searching: false,
          serverResponseItems: [],
          localResponseItems: [],
          combinedResponseItems: {},
          resultSummaries: [],
          generatingAIOverview: false,
        ),
      );
    } else {
      emit(state.copyWith(query: event.search, searching: true));
      _activeQuery = event.search;

      unawaited(
        SearchBackendService.performSearch(
          event.search,
        ).then(
          (result) => result.fold(
            (stream) {
              if (!isClosed && _activeQuery == event.search) {
                add(CommandPaletteEvent.newSearchStream(stream: stream));
              }
            },
            (error) {
              if (!isClosed) {
                add(
                  CommandPaletteEvent.resultsChanged(
                    searchId: '',
                    searching: false,
                    generatingAIOverview: false,
                  ),
                );
              }
            },
          ),
        ),
      );
    }
  }

  FutureOr<void> _onNewSearchStream(
    CommandPaletteNewSearchStreamEvent event,
    Emitter<CommandPaletteState> emit,
  ) {
    state.searchResponseStream?.dispose();
    emit(
      state.copyWith(
        searchId: event.stream.searchId,
        searchResponseStream: event.stream,
      ),
    );

    event.stream.listen(
      onLocalItems: (items, searchId) => _handleResultsUpdate(
        searchId: searchId,
        localItems: items,
      ),
      onServerItems: (items, searchId, searching, generatingAIOverview) =>
          _handleResultsUpdate(
        searchId: searchId,
        summaries: [], // when got server search result, summaries should be empty
        serverItems: items,
        searching: searching,
        generatingAIOverview: generatingAIOverview,
      ),
      onSummaries: (summaries, searchId, searching, generatingAIOverview) =>
          _handleResultsUpdate(
        searchId: searchId,
        summaries: summaries,
        searching: searching,
        generatingAIOverview: generatingAIOverview,
      ),
      onFinished: (searchId) => _handleResultsUpdate(
        searchId: searchId,
        searching: false,
      ),
    );
  }

  void _handleResultsUpdate({
    required String searchId,
    List<SearchResponseItemPB>? serverItems,
    List<LocalSearchResponseItemPB>? localItems,
    List<SearchSummaryPB>? summaries,
    bool searching = true,
    bool generatingAIOverview = false,
  }) {
    if (_isActiveSearch(searchId)) {
      add(
        CommandPaletteEvent.resultsChanged(
          searchId: searchId,
          serverItems: serverItems,
          localItems: localItems,
          summaries: summaries,
          searching: searching,
          generatingAIOverview: generatingAIOverview,
        ),
      );
    }
  }

  FutureOr<void> _onResultsChanged(
    CommandPaletteResultsChangedEvent event,
    Emitter<CommandPaletteState> emit,
  ) async {
    if (state.searchId != event.searchId) return;

    final Map<String, SearchResultItem> combinedItems = {};
    for (final item in event.serverItems ?? state.serverResponseItems) {
      combinedItems[item.id] = SearchResultItem(
        id: item.id,
        icon: item.icon,
        displayName: item.displayName,
        content: item.content,
        workspaceId: item.workspaceId,
      );
    }

    for (final item in event.localItems ?? state.localResponseItems) {
      combinedItems.putIfAbsent(
        item.id,
        () => SearchResultItem(
          id: item.id,
          icon: item.icon,
          displayName: item.displayName,
          content: '',
          workspaceId: item.workspaceId,
        ),
      );
    }

    if (_myRole == AFRolePB.Guest) {
      final result = await FolderEventGetFlattenSharedPages().send();
      final flattenViewIds = result.fold(
        (views) => views.items.map((e) => e.id).toList(),
        (error) => [],
      );
      // remove the views that are not in the flattenViewIds
      combinedItems.removeWhere((key, value) => !flattenViewIds.contains(key));
    }

    emit(
      state.copyWith(
        serverResponseItems: event.serverItems ?? state.serverResponseItems,
        localResponseItems: event.localItems ?? state.localResponseItems,
        resultSummaries: event.summaries ?? state.resultSummaries,
        combinedResponseItems: combinedItems,
        searching: event.searching,
        generatingAIOverview: event.generatingAIOverview,
      ),
    );
  }

  FutureOr<void> _onTrashChanged(
    CommandPaletteTrashChangedEvent event,
    Emitter<CommandPaletteState> emit,
  ) async {
    if (event.trash != null) {
      emit(state.copyWith(trash: event.trash!));
    } else {
      final trashOrFailure = await _trashService.readTrash();
      trashOrFailure.fold((trash) {
        emit(state.copyWith(trash: trash.items));
      }, (error) {
        // Optionally handle error; otherwise, we simply do nothing.
      });
    }
  }

  FutureOr<void> _onWorkspaceChanged(
    CommandPaletteWorkspaceChangedEvent event,
    Emitter<CommandPaletteState> emit,
  ) {
    emit(
      state.copyWith(
        query: '',
        serverResponseItems: [],
        localResponseItems: [],
        combinedResponseItems: {},
        resultSummaries: [],
        searching: false,
        generatingAIOverview: false,
      ),
    );
    _refreshCachedViews();
  }

  FutureOr<void> _onClearSearch(
    CommandPaletteClearSearchEvent event,
    Emitter<CommandPaletteState> emit,
  ) {
    emit(CommandPaletteState.initial().copyWith(trash: state.trash));
  }

  FutureOr<void> _onGoingToAskAI(
    CommandPaletteGoingToAskAIEvent event,
    Emitter<CommandPaletteState> emit,
  ) {
    emit(state.copyWith(askAI: true, askAISources: event.sources));
  }

  FutureOr<void> _onAskedAI(
    CommandPaletteAskedAIEvent event,
    Emitter<CommandPaletteState> emit,
  ) {
    emit(state.copyWith(askAI: false));
  }

  bool _isActiveSearch(String searchId) =>
      !isClosed && state.searchId == searchId;
}
