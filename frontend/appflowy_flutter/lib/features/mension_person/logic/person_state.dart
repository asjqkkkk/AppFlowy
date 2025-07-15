import 'package:appflowy/features/mension_person/data/models/person.dart';

class PersonState {
  factory PersonState.initial() => PersonState(
        personWithAccess:
            PersonWithAccess(person: Person.empty(), access: false),
      );

  const PersonState({
    required this.personWithAccess,
    this.documentId = '',
    this.getPersonFailedMesssage = '',
    this.status = PersonStatus.loading,
  });

  final PersonWithAccess personWithAccess;
  final String documentId;
  final String getPersonFailedMesssage;
  final PersonStatus status;

  bool get isLoading => status == PersonStatus.loading;
  bool get isIdle => status == PersonStatus.idle;
  Person get person => personWithAccess.person;
  bool get access => personWithAccess.access;

  PersonState copyWith({
    PersonWithAccess? personWithAccess,
    String? documentId,
    String? getPersonFailedMesssage,
    PersonStatus? status,
  }) {
    return PersonState(
      personWithAccess: personWithAccess ?? this.personWithAccess,
      documentId: documentId ?? this.documentId,
      getPersonFailedMesssage:
          getPersonFailedMesssage ?? this.getPersonFailedMesssage,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PersonState &&
        other.personWithAccess == personWithAccess &&
        other.documentId == documentId &&
        other.getPersonFailedMesssage == getPersonFailedMesssage &&
        other.status == status;
  }

  @override
  int get hashCode {
    return personWithAccess.hashCode ^
        documentId.hashCode ^
        getPersonFailedMesssage.hashCode ^
        status.hashCode;
  }

  @override
  String toString() {
    return 'PersonState(personWithAccess: $personWithAccess, documentId: $documentId, getPersonFailedMesssage: $getPersonFailedMesssage, status: $status)';
  }
}

enum PersonStatus { loading, idle, error }
