import 'package:appflowy/features/mension_person/data/models/models.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:flutter/widgets.dart';

class MentionState {
  MentionState({
    this.persons = const [],
    this.views = const [],
    this.filterViews = const [],
    this.sendNotification = false,
    this.focusId,
    this.query = '',
    this.selectedId = '',
    this.showMorePersons = false,
    this.showMorePage = false,
    this.visibleItems = const {},
    required this.itemMap,
    this.executedItem,
  });

  final List<MentionablePersonPB> persons;
  final List<ViewPB> views;
  final List<ViewPB> filterViews;
  final bool sendNotification;
  final String? focusId;
  final String query;
  final String selectedId;
  final bool showMorePersons;
  final bool showMorePage;
  final Set<String> visibleItems;
  final MentionItemMap itemMap;
  final MentionMenuItem? executedItem;

  MentionState copyWith({
    List<MentionablePersonPB>? persons,
    List<ViewPB>? views,
    List<ViewPB>? filterViews,
    bool? sendNotification,
    ValueGetter<String?>? focusId,
    String? query,
    String? selectedId,
    bool? showMorePersons,
    bool? showMorePage,
    Set<String>? visibleItems,
    MentionItemMap? itemMap,
    MentionMenuItem? executedItem,
  }) {
    return MentionState(
      persons: persons ?? this.persons,
      views: views ?? this.views,
      filterViews: filterViews ?? this.filterViews,
      sendNotification: sendNotification ?? this.sendNotification,
      focusId: focusId != null ? focusId() : this.focusId,
      query: query ?? this.query,
      selectedId: selectedId ?? this.selectedId,
      showMorePersons: showMorePersons ?? this.showMorePersons,
      showMorePage: showMorePage ?? this.showMorePage,
      visibleItems: visibleItems ?? this.visibleItems,
      itemMap: itemMap ?? this.itemMap,
      executedItem: executedItem ?? this.executedItem,
    );
  }
}
