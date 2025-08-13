import 'dart:math';

import 'package:appflowy/features/mension_person/data/models/invite.dart';
import 'package:appflowy_backend/protobuf/flowy-error/code.pbenum.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';

import 'mention_repository.dart';

class MockMentionRepository extends MentionRepository {
  @override
  Future<FlowyResult<List<MentionablePersonPB>, FlowyError>>
      getWorkspacePersons({
    required String workspaceId,
    required String query,
  }) async {
    final persons = _MockState.getInstance().persons;
    if (query.trim().isNotEmpty) {
      final formatedQuery = query.trim().toLowerCase();
      final filteredPersons = persons
          .where(
            (p) =>
                p.name.toLowerCase().contains(formatedQuery) ||
                p.email.toLowerCase().contains(formatedQuery),
          )
          .toList();
      return FlowySuccess(filteredPersons);
    }
    return FlowySuccess(persons);
  }

  @override
  Future<FlowyResult<MentionablePersonPB, FlowyError>> invitePerson({
    required String workspaceId,
    required InviteInfo info,
  }) async {
    try {
      final person = _MockState.getInstance().invitePerson(info);
      return FlowySuccess(person);
    } on FormatException catch (e) {
      return FlowyFailure(
        FlowyError(code: ErrorCode.EmailAlreadyExists, msg: e.message),
      );
    }
  }

  @override
  Future<FlowyResult<void, FlowyError>> mentionPerson({
    required String documentId,
    required String personId,
    required String ancestorId,
    required bool requireNotification,
    String? blockId,
  }) async {
    return FlowySuccess(null);
  }
}

class _MockState {
  _MockState._();

  static _MockState? _instance;

  static _MockState getInstance() {
    _instance ??= _MockState._();
    return _instance!;
  }

  final List<MentionablePersonPB> persons = [
    MentionablePersonPB(
      uuid: '1',
      name: 'Andrew Christian',
      role: MentionablePersonTypePB.WorkspaceMember,
      email: 'andrewchristian@appflowy.io',
      coverImageUrl: _coverImageUrl,
      avatarUrl: 'https://avatar.iran.liara.run/public',
    ),
    MentionablePersonPB(
      uuid: '2',
      name: 'Andrew Tate',
      role: MentionablePersonTypePB.WorkspaceMember,
      email: 'andrewtate@appflowy.io',
      description: 'A famous internet personality ',
      coverImageUrl: _coverImageUrl,
      avatarUrl: 'https://avatar.iran.liara.run/public/boy',
    ),
    MentionablePersonPB(
      uuid: '3',
      name: 'Emma Johnson',
      role: MentionablePersonTypePB.WorkspaceMember,
      email: 'emmajohnson@appflowy.io',
      avatarUrl: 'https://avatar.iran.liara.run/public/girl',
    ),
    MentionablePersonPB(
      uuid: '4',
      name: 'Michael Brown',
      role: MentionablePersonTypePB.WorkspaceMember,
      email: 'michaelbrown@appflowy.io',
      avatarUrl: 'https://avatar.iran.liara.run/public/boy/13',
    ),
    MentionablePersonPB(
      uuid: '5',
      name: 'Nathan Brooks',
      role: MentionablePersonTypePB.WorkspaceMember,
      email: 'nathanbrooks@appflowy.io',
      avatarUrl: 'https://avatar.iran.liara.run/public/boy/10',
    ),
  ];

  MentionablePersonPB invitePerson(InviteInfo info) {
    final index = persons.indexWhere((p) => p.email == info.email);
    if (index != -1) {
      throw FormatException('Person with email ${info.email} already exists');
    }
    final person = MentionablePersonPB(
      uuid: DateTime.now().millisecondsSinceEpoch.toString(),
      name: info.contactDetail?.name ?? info.email,
      role: info.role,
      email: info.email,
      description: info.contactDetail?.description ?? '',
      avatarUrl: randomAvatarUrl,
      coverImageUrl: Random().nextBool() ? null : _coverImageUrl,
    );
    persons.add(person);
    return person;
  }

  String get randomAvatarUrl =>
      'https://avatar.iran.liara.run/public/${Random().nextBool() ? 'boy' : 'girl'}/${Random().nextInt(100)}';
}

const String _coverImageUrl =
    'https://images.unsplash.com/photo-1748882145961-536cc88fd117?q=80&w=2624&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D';
