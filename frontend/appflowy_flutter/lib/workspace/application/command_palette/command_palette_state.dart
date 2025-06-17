import 'package:appflowy/workspace/application/command_palette/search_service.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-search/result.pb.dart';

class SearchResultItem {
  const SearchResultItem({
    required this.id,
    required this.icon,
    required this.content,
    required this.displayName,
    this.workspaceId,
  });

  final String id;
  final String content;
  final ResultIconPB icon;
  final String displayName;
  final String? workspaceId;
}

class CommandPaletteState {
  factory CommandPaletteState.initial() => const CommandPaletteState(
        query: null,
        serverResponseItems: [],
        localResponseItems: [],
        combinedResponseItems: {},
        cachedViews: {},
        resultSummaries: [],
        searchResponseStream: null,
        searching: false,
        generatingAIOverview: false,
        askAI: false,
        askAISources: null,
        trash: [],
        searchId: null,
      );

  const CommandPaletteState({
    required this.query,
    required this.serverResponseItems,
    required this.localResponseItems,
    required this.combinedResponseItems,
    required this.cachedViews,
    required this.resultSummaries,
    required this.searchResponseStream,
    required this.searching,
    required this.generatingAIOverview,
    required this.askAI,
    required this.askAISources,
    required this.trash,
    required this.searchId,
  });

  final String? query;
  final List<SearchResponseItemPB> serverResponseItems;
  final List<LocalSearchResponseItemPB> localResponseItems;
  final Map<String, SearchResultItem> combinedResponseItems;
  final Map<String, ViewPB> cachedViews;
  final List<SearchSummaryPB> resultSummaries;
  final SearchResponseStream? searchResponseStream;
  final bool searching;
  final bool generatingAIOverview;
  final bool askAI;
  final List<SearchSourcePB>? askAISources;
  final List<TrashPB> trash;
  final String? searchId;

  CommandPaletteState copyWith({
    String? query,
    List<SearchResponseItemPB>? serverResponseItems,
    List<LocalSearchResponseItemPB>? localResponseItems,
    Map<String, SearchResultItem>? combinedResponseItems,
    Map<String, ViewPB>? cachedViews,
    List<SearchSummaryPB>? resultSummaries,
    SearchResponseStream? searchResponseStream,
    bool? searching,
    bool? generatingAIOverview,
    bool? askAI,
    List<SearchSourcePB>? askAISources,
    List<TrashPB>? trash,
    String? searchId,
  }) {
    return CommandPaletteState(
      query: query ?? this.query,
      serverResponseItems: serverResponseItems ?? this.serverResponseItems,
      localResponseItems: localResponseItems ?? this.localResponseItems,
      combinedResponseItems:
          combinedResponseItems ?? this.combinedResponseItems,
      cachedViews: cachedViews ?? this.cachedViews,
      resultSummaries: resultSummaries ?? this.resultSummaries,
      searchResponseStream: searchResponseStream ?? this.searchResponseStream,
      searching: searching ?? this.searching,
      generatingAIOverview: generatingAIOverview ?? this.generatingAIOverview,
      askAI: askAI ?? this.askAI,
      askAISources: askAISources ?? this.askAISources,
      trash: trash ?? this.trash,
      searchId: searchId ?? this.searchId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CommandPaletteState &&
        other.query == query &&
        other.searching == searching &&
        other.generatingAIOverview == generatingAIOverview &&
        other.askAI == askAI &&
        other.searchId == searchId;
  }

  @override
  int get hashCode {
    return Object.hash(
      query,
      searching,
      generatingAIOverview,
      askAI,
      searchId,
    );
  }

  @override
  String toString() {
    return 'CommandPaletteState(query: $query, searching: $searching, generatingAIOverview: $generatingAIOverview, askAI: $askAI, searchId: $searchId)';
  }
}
