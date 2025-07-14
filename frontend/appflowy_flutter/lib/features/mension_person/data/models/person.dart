import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';

class Person {
  Person({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
    this.coverImageUrl,
    this.description,
    this.invited = false,
    this.deleted = false,
  });

  Person.empty()
      : id = '',
        name = '',
        email = '',
        role = PersonRole.member,
        avatarUrl = null,
        coverImageUrl = null,
        description = null,
        invited = false,
        deleted = false;

  Person.fromProto(MentionablePersonPB person)
      : id = person.uuid,
        name = person.name,
        email = person.email,
        role = _fromProtoRole(person.role),
        avatarUrl = person.avatarUrl,
        coverImageUrl = person.coverImageUrl,
        description = person.description,
        invited = person.invited,
        deleted = false;

  final String id;
  final String name;
  final String email;
  final PersonRole role;
  final String? avatarUrl;
  final String? coverImageUrl;
  final String? description;
  final bool invited;
  final bool deleted;

  bool get isEmpty => id.isEmpty || email.isEmpty;

  static PersonRole _fromProtoRole(MentionablePersonTypePB role) {
    switch (role) {
      case MentionablePersonTypePB.WorkspaceMember:
        return PersonRole.member;
      case MentionablePersonTypePB.WorkspaceGuest:
        return PersonRole.guest;
      case MentionablePersonTypePB.Contact:
        return PersonRole.contact;
    }
    return PersonRole.member;
  }
}

enum PersonRole {
  member,
  guest,
  contact,
}

class PersonWithAccess {
  PersonWithAccess({required this.person, required this.access});

  final Person person;
  final bool access;
}
