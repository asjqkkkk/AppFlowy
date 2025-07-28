import 'package:appflowy/features/mension_person/data/models/person.dart';
import 'package:equatable/equatable.dart';

class PersonState {
  factory PersonState.initial() => PersonState();

  const PersonState({
    this.persons = const [],
    this.availableEmails = const [],
    this.status = PersonStatus.loading,
    this.mentionedErrorPerson,
    this.mentionedSucceedPerson,
  });

  final List<Person> persons;
  final List<String> availableEmails;
  final PersonStatus status;
  final PersonWithNotifyTimes? mentionedErrorPerson;
  final PersonWithNotifyTimes? mentionedSucceedPerson;

  bool get isLoading => status == PersonStatus.loading;
  bool get isIdle => status == PersonStatus.idle;

  bool hasAccess(String email) => availableEmails.contains(email);

  PersonState copyWith({
    List<Person>? persons,
    List<String>? availableEmails,
    PersonStatus? status,
    PersonWithNotifyTimes? mentionedErrorPerson,
    PersonWithNotifyTimes? mentionedSucceedPerson,
  }) {
    return PersonState(
      persons: persons ?? this.persons,
      availableEmails: availableEmails ?? this.availableEmails,
      status: status ?? this.status,
      mentionedErrorPerson: mentionedErrorPerson ?? this.mentionedErrorPerson,
      mentionedSucceedPerson:
          mentionedSucceedPerson ?? this.mentionedSucceedPerson,
    );
  }
}

enum PersonStatus { loading, idle, error }

class PersonWithNotifyTimes extends Equatable {
  const PersonWithNotifyTimes({
    required this.person,
    required this.notifyTimes,
  });

  final Person person;
  final int notifyTimes;

  String get name => person.name;

  @override
  List<Object?> get props => [person, notifyTimes];
}
