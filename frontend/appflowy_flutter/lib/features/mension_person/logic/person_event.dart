import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';

sealed class PersonEvent {
  const PersonEvent();

  const factory PersonEvent.initial() = InitialEvent;

  const factory PersonEvent.removePersons(List<String> personIds) =
      RemovePersonsEvent;

  const factory PersonEvent.notifyPerson({
    String? blockId,
    required MentionablePersonPB person,
    required String ancestorId,
  }) = NotifyPersonEvent;

  const factory PersonEvent.updatePersons(List<MentionablePersonPB> persons) =
      UpdatePersonsEvent;

  const factory PersonEvent.reloadPersons(List<MentionablePersonPB> persons) =
      ReloadPersonsEvent;

  const factory PersonEvent.updateAvailableEmails(List<String> emails) =
      UpdateAvailableEmailsEvent;
}

class InitialEvent implements PersonEvent {
  const InitialEvent();
}

class UpdatePersonsEvent implements PersonEvent {
  const UpdatePersonsEvent(this.persons);
  final List<MentionablePersonPB> persons;
}

class ReloadPersonsEvent implements PersonEvent {
  const ReloadPersonsEvent(this.persons);
  final List<MentionablePersonPB> persons;
}

class RemovePersonsEvent implements PersonEvent {
  const RemovePersonsEvent(this.personIds);
  final List<String> personIds;
}

class UpdateAvailableEmailsEvent implements PersonEvent {
  const UpdateAvailableEmailsEvent(this.emails);
  final List<String> emails;
}

class NotifyPersonEvent implements PersonEvent {
  const NotifyPersonEvent({
    this.blockId,
    required this.person,
    required this.ancestorId,
  });

  final String? blockId;
  final String ancestorId;
  final MentionablePersonPB person;
}
