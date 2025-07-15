import 'package:appflowy/features/mension_person/data/models/person.dart';

import 'person_state.dart';

sealed class PersonEvent {
  const PersonEvent();

  const factory PersonEvent.initial() = InitialEvent;

  const factory PersonEvent.updatePerson(PersonWithAccess person) =
      UpdatePersonEvent;

  const factory PersonEvent.updateStatusEvent({
    required PersonStatus status,
    String? errorMessage,
  }) = UpdateStatusEvent;
}

class InitialEvent implements PersonEvent {
  const InitialEvent();
}

class UpdatePersonEvent implements PersonEvent {
  const UpdatePersonEvent(this.person);

  final PersonWithAccess person;
}

class UpdateStatusEvent implements PersonEvent {
  const UpdateStatusEvent({
    required this.status,
    this.errorMessage,
  });

  final PersonStatus status;
  final String? errorMessage;
}
