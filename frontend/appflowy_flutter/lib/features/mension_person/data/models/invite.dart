import 'package:appflowy_backend/protobuf/flowy-folder/view.pbenum.dart';

class InviteInfo {
  InviteInfo({
    required this.email,
    this.role = MentionablePersonTypePB.WorkspaceMember,
    this.contactDetail,
  });

  final String email;
  final MentionablePersonTypePB role;
  final ContactDetail? contactDetail;

  InviteInfo copyWith({
    String? email,
    MentionablePersonTypePB? role,
    ContactDetail? contactDetail,
  }) {
    return InviteInfo(
      email: email ?? this.email,
      role: role ?? this.role,
      contactDetail: contactDetail ?? this.contactDetail,
    );
  }
}

class ContactDetail {
  ContactDetail({
    this.name = '',
    this.description = '',
  });

  final String name;
  final String description;

  ContactDetail copyWith({
    String? name,
    String? description,
  }) {
    return ContactDetail(
      name: name ?? this.name,
      description: description ?? this.description,
    );
  }
}
