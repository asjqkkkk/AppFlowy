import 'package:appflowy/workspace/application/command_palette/search_service.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart'
    hide AFRolePB;
import 'package:appflowy_backend/protobuf/flowy-search/result.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';

sealed class CommandPaletteEvent {
  const CommandPaletteEvent();

  /// Event triggered when search text changes
  const factory CommandPaletteEvent.searchChanged({
    required String search,
    AFRolePB? role,
  }) = CommandPaletteSearchChangedEvent;

  /// Event to perform search with the given search string
  const factory CommandPaletteEvent.performSearch({
    required String search,
  }) = CommandPalettePerformSearchEvent;

  /// Event to handle new search stream
  const factory CommandPaletteEvent.newSearchStream({
    required SearchResponseStream stream,
  }) = CommandPaletteNewSearchStreamEvent;

  /// Event to update search results
  const factory CommandPaletteEvent.resultsChanged({
    required String searchId,
    required bool searching,
    required bool generatingAIOverview,
    List<SearchResponseItemPB>? serverItems,
    List<LocalSearchResponseItemPB>? localItems,
    List<SearchSummaryPB>? summaries,
  }) = CommandPaletteResultsChangedEvent;

  /// Event to update trash items
  const factory CommandPaletteEvent.trashChanged({
    List<TrashPB>? trash,
  }) = CommandPaletteTrashChangedEvent;

  /// Event when workspace changes
  const factory CommandPaletteEvent.workspaceChanged({
    String? workspaceId,
  }) = CommandPaletteWorkspaceChangedEvent;

  /// Event to clear search
  const factory CommandPaletteEvent.clearSearch() =
      CommandPaletteClearSearchEvent;

  /// Event when user is going to ask AI
  const factory CommandPaletteEvent.goingToAskAI({
    List<SearchSourcePB>? sources,
  }) = CommandPaletteGoingToAskAIEvent;

  /// Event when user has asked AI
  const factory CommandPaletteEvent.askedAI() = CommandPaletteAskedAIEvent;

  /// Event to refresh cached views
  const factory CommandPaletteEvent.refreshCachedViews() =
      CommandPaletteRefreshCachedViewsEvent;

  /// Event to update cached views
  const factory CommandPaletteEvent.updateCachedViews({
    required List<ViewPB> views,
  }) = CommandPaletteUpdateCachedViewsEvent;
}

class CommandPaletteSearchChangedEvent extends CommandPaletteEvent {
  const CommandPaletteSearchChangedEvent({
    required this.search,
    this.role,
  });

  final String search;
  final AFRolePB? role;
}

class CommandPalettePerformSearchEvent extends CommandPaletteEvent {
  const CommandPalettePerformSearchEvent({required this.search});

  final String search;
}

class CommandPaletteNewSearchStreamEvent extends CommandPaletteEvent {
  const CommandPaletteNewSearchStreamEvent({required this.stream});

  final SearchResponseStream stream;
}

class CommandPaletteResultsChangedEvent extends CommandPaletteEvent {
  const CommandPaletteResultsChangedEvent({
    required this.searchId,
    required this.searching,
    required this.generatingAIOverview,
    this.serverItems,
    this.localItems,
    this.summaries,
  });

  final String searchId;
  final bool searching;
  final bool generatingAIOverview;
  final List<SearchResponseItemPB>? serverItems;
  final List<LocalSearchResponseItemPB>? localItems;
  final List<SearchSummaryPB>? summaries;
}

class CommandPaletteTrashChangedEvent extends CommandPaletteEvent {
  const CommandPaletteTrashChangedEvent({this.trash});

  final List<TrashPB>? trash;
}

class CommandPaletteWorkspaceChangedEvent extends CommandPaletteEvent {
  const CommandPaletteWorkspaceChangedEvent({this.workspaceId});

  final String? workspaceId;
}

class CommandPaletteClearSearchEvent extends CommandPaletteEvent {
  const CommandPaletteClearSearchEvent();
}

class CommandPaletteGoingToAskAIEvent extends CommandPaletteEvent {
  const CommandPaletteGoingToAskAIEvent({this.sources});

  final List<SearchSourcePB>? sources;
}

class CommandPaletteAskedAIEvent extends CommandPaletteEvent {
  const CommandPaletteAskedAIEvent();
}

class CommandPaletteRefreshCachedViewsEvent extends CommandPaletteEvent {
  const CommandPaletteRefreshCachedViewsEvent();
}

class CommandPaletteUpdateCachedViewsEvent extends CommandPaletteEvent {
  const CommandPaletteUpdateCachedViewsEvent({required this.views});
  final List<ViewPB> views;
}
