import 'package:appflowy/features/mension_person/data/models/person.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

class MentionState {
  MentionState({
    this.persons = const [],
    this.personsWithAccess = const [],
    this.sendNotification = false,
    this.focusId,
    this.query = '',
    this.selectedId = '',
    this.showMorePersons = false,
    this.showMorePage = false,
    this.visibleItems = const {},
  });

  final List<Person> persons;
  final List<PersonWithAccess> personsWithAccess;
  final bool sendNotification;
  final String? focusId;
  final String query;
  final String selectedId;
  final bool showMorePersons;
  final bool showMorePage;
  final Set<String> visibleItems;

  MentionState copyWith({
    List<Person>? persons,
    List<PersonWithAccess>? personsWithAccess,
    bool? sendNotification,
    ValueGetter<String?>? focusId,
    String? query,
    String? selectedId,
    bool? showMorePersons,
    bool? showMorePage,
    Set<String>? visibleItems,
  }) {
    return MentionState(
      persons: persons ?? this.persons,
      personsWithAccess: personsWithAccess ?? this.personsWithAccess,
      sendNotification: sendNotification ?? this.sendNotification,
      focusId: focusId != null ? focusId() : this.focusId,
      query: query ?? this.query,
      selectedId: selectedId ?? this.selectedId,
      showMorePersons: showMorePersons ?? this.showMorePersons,
      showMorePage: showMorePage ?? this.showMorePage,
      visibleItems: visibleItems ?? this.visibleItems,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final collectionEquals = const DeepCollectionEquality().equals;

    return other is MentionState &&
        collectionEquals(other.persons, persons) &&
        collectionEquals(other.personsWithAccess, personsWithAccess) &&
        other.sendNotification == sendNotification &&
        other.focusId == focusId &&
        other.query == query &&
        other.selectedId == selectedId &&
        other.showMorePersons == showMorePersons &&
        other.showMorePage == showMorePage &&
        collectionEquals(other.visibleItems, visibleItems);
  }

  @override
  int get hashCode {
    return persons.hashCode ^
        personsWithAccess.hashCode ^
        sendNotification.hashCode ^
        focusId.hashCode ^
        query.hashCode ^
        selectedId.hashCode ^
        showMorePersons.hashCode ^
        showMorePage.hashCode ^
        visibleItems.hashCode;
  }
}
