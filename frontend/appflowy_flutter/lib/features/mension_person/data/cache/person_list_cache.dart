import 'package:appflowy/features/mension_person/data/models/models.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';
import 'package:appflowy_backend/log.dart';
import 'package:flutter/material.dart';

class PersonListMemoryCache {
  final Map<String, List<Person>> _cache = {};

  void updatePersonList(String workspaceId, List<Person> persons) {
    _cache[workspaceId] = List.of(persons);
  }

  List<Person>? getPersons(String workspaceId) {
    final persons = _cache[workspaceId];
    if (persons == null) return null;
    return List.of(persons);
  }
}

class PersonListWithAccessMemoryCache {
  /// the key is [documentId]
  final Map<String, List<PersonWithAccess>> _cache = {};
  final Map<String, Set<ValueChanged<PersonListWithAccessAndResult>>>
      _callbacks = {};

  void onPersonListWithAcessFetched(
    String documentId,
    ValueChanged<PersonListWithAccessAndResult> callback,
  ) {
    final set = _callbacks[documentId] ?? {};
    if (set.isEmpty) {
      set.add(callback);
      _callbacks[documentId] = set;
      ViewBackendService.getPageMentionablePersons(documentId).then((r) {
        final copySet = Set<ValueChanged<PersonListWithAccessAndResult>>.of(
          _callbacks[documentId] ?? {},
        );
        r.fold((s) {
          final persons = s.persons
              .map(
                (e) => PersonWithAccess(
                  access: e.canAccessPage,
                  person: Person.fromProto(e.person),
                ),
              )
              .toList();
          _cache[documentId] = List.of(persons);
          for (final c in copySet) {
            c.call(
              PersonListWithAccessAndResult(persons: persons, succeed: true),
            );
          }
        }, (e) {
          Log.error('onPersonListWithAcessFetched error: $e');
          for (final c in copySet) {
            c.call(PersonListWithAccessAndResult(persons: [], succeed: false));
          }
        });
      });
    } else {
      set.add(callback);
      _callbacks[documentId] = set;
    }
  }

  void removePersonListWithAcessFetchedCallback(
    String documentId,
    ValueChanged<PersonListWithAccessAndResult> callback,
  ) {
    final set = _callbacks[documentId] ?? {};
    set.remove(callback);
    _callbacks[documentId] = set;
  }

  List<PersonWithAccess>? getPersonsWithAccess(String documentId) {
    final persons = _cache[documentId];
    if (persons == null) return null;
    return List.of(persons);
  }

  void updatePersonWithAccess(
    String documentId,
    PersonWithAccess person,
  ) {
    final persons = _cache[documentId];
    if (persons == null) return;
    final index = persons.indexWhere((e) => e.person.id == e.person.id);
    if (index == -1) return;
    persons[index] = person;
    _cache[documentId] = persons;
  }
}

class PersonListWithAccessAndResult {
  PersonListWithAccessAndResult({required this.persons, required this.succeed});

  final List<PersonWithAccess> persons;
  final bool succeed;
}
