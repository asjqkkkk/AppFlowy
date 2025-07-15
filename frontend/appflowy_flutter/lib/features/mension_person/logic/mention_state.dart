import 'package:appflowy/features/mension_person/data/models/person.dart';
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
    this.dividerInfo = const MentionMenuDivider(),
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
  final MentionMenuDivider dividerInfo;

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
    MentionMenuDivider? dividerInfo,
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
      dividerInfo: dividerInfo ?? this.dividerInfo,
    );
  }
}

class MentionMenuDivider {
  const MentionMenuDivider({
    this.hasPersons = false,
    this.hasPages = false,
    this.hasDateOrReminders = true,
  });

  final bool hasPersons;
  final bool hasPages;
  final bool hasDateOrReminders;

  MentionMenuDivider copyWith({
    bool? hasPersons,
    bool? hasPages,
    bool? hasDateOrReminders,
  }) {
    return MentionMenuDivider(
      hasPersons: hasPersons ?? this.hasPersons,
      hasPages: hasPages ?? this.hasPages,
      hasDateOrReminders: hasDateOrReminders ?? this.hasDateOrReminders,
    );
  }
}
