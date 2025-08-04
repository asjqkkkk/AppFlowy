import 'package:appflowy/features/mension_person/data/models/person.dart';

sealed class PersonEvent {
  const PersonEvent();

  const factory PersonEvent.initial() = InitialEvent;

  const factory PersonEvent.updatePerson(Person person) = UpdatePersonEvent;

  const factory PersonEvent.notifyPerson({
    String? blockId,
    required Person person,
  }) = NotifyPersonEvent;

  const factory PersonEvent.updatePersons(List<Person> persons) =
      UpdatePersonsEvent;

  const factory PersonEvent.updateAvailableEmails(List<String> emails) =
      UpdateAvailableEmailsEvent;
}

class InitialEvent implements PersonEvent {
  const InitialEvent();
}

class UpdatePersonEvent implements PersonEvent {
  const UpdatePersonEvent(this.person);

  final Person person;
}

class UpdatePersonsEvent implements PersonEvent {
  const UpdatePersonsEvent(this.persons);
  final List<Person> persons;
}

class UpdateAvailableEmailsEvent implements PersonEvent {
  const UpdateAvailableEmailsEvent(this.emails);
  final List<String> emails;
}

class NotifyPersonEvent implements PersonEvent {
  const NotifyPersonEvent({
    this.blockId,
    required this.person,
  });
  final String? blockId;
  final Person person;
}
