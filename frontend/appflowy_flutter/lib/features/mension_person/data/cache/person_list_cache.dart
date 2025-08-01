import 'package:appflowy/features/mension_person/data/models/models.dart';

class PersonListMemoryCache {
  final Map<String, List<Person>> _cache = {};

  void updatePersonList(String workspaceId, List<Person> persons) {
    _cache[workspaceId] = List.of(persons);
  }

  void updatePerson(String workspaceId, Person person) {
    final persons = _cache[workspaceId] ?? <Person>[];
    final index = persons.indexWhere((e) => e.id == person.id);
    if (index != -1) {
      persons[index] = person;
    }
    _cache[workspaceId] = persons;
  }

  List<Person>? getPersons(String workspaceId) {
    final persons = _cache[workspaceId];
    if (persons == null) return null;
    return List.of(persons);
  }

  void movePersonToTop(String workspaceId, String personId) {
    final persons = _cache[workspaceId];
    if (persons == null) return;
    final index = persons.indexWhere((e) => e.id == personId);
    if (index == -1) return;
    final person = persons.removeAt(index);
    persons.insert(0, person);
    _cache[workspaceId] = persons;
  }
}
