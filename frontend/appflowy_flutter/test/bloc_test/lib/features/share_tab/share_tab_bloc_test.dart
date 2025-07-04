import 'package:appflowy/features/share_tab/data/models/models.dart';
import 'package:appflowy/features/share_tab/data/repositories/local_share_with_user_repository_impl.dart';
import 'package:appflowy/features/share_tab/logic/share_tab_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const pageId = 'test_page_id';
  const workspaceId = 'test_workspace_id';
  late LocalShareWithUserRepositoryImpl repository;
  late ShareTabBloc bloc;

  setUp(() {
    repository = LocalShareWithUserRepositoryImpl();
    bloc = ShareTabBloc(
      repository: repository,
      pageId: pageId,
      workspaceId: workspaceId,
    )..add(ShareTabEvent.initialize());
  });

  tearDown(() async {
    await bloc.close();
  });

  const email = 'lucas.xu@appflowy.io';

  group('ShareTabBloc', () {
    blocTest<ShareTabBloc, ShareTabState>(
      'shares page with user',
      build: () => bloc,
      act: (bloc) => bloc.add(
        ShareTabEvent.inviteUsers(
          emails: [email],
          accessLevel: ShareAccessLevel.readOnly,
        ),
      ),
      wait: const Duration(milliseconds: 100),
      expect: () => [
        // First state: initial empty state
        isA<ShareTabState>().having(
          (s) => s.shareResult,
          'shareResult',
          isNull,
        ),
        // Second state: after initialization (currentUser, shareLink set, shareResult still null)
        isA<ShareTabState>()
            .having((s) => s.shareResult, 'shareResult', isNull)
            .having((s) => s.currentUser, 'currentUser', isNotNull)
            .having((s) => s.shareLink, 'shareLink', isNotEmpty),
        // Third state: shareResult is Success and users updated
        isA<ShareTabState>()
            .having((s) => s.shareResult, 'shareResult', isNotNull)
            .having(
              (s) => s.users.any((u) => u.email == email),
              'users contains new user',
              isTrue,
            ),
      ],
    );

    blocTest<ShareTabBloc, ShareTabState>(
      'removes user from page',
      build: () => bloc,
      act: (bloc) => bloc.add(
        ShareTabEvent.removeUsers(
          emails: [email],
        ),
      ),
      wait: const Duration(milliseconds: 100),
      expect: () => [
        // First state: initial empty state
        isA<ShareTabState>()
            .having((s) => s.removeResult, 'removeResult', isNull),
        // Second state: after initialization (currentUser, shareLink set, removeResult still null)
        isA<ShareTabState>()
            .having((s) => s.removeResult, 'removeResult', isNull)
            .having((s) => s.currentUser, 'currentUser', isNotNull)
            .having((s) => s.shareLink, 'shareLink', isNotEmpty),
        // Third state: removeResult is Success and users updated
        isA<ShareTabState>()
            .having((s) => s.removeResult, 'removeResult', isNotNull)
            .having(
              (s) => s.users.any((u) => u.email == email),
              'users contains removed user',
              isFalse,
            ),
      ],
    );

    blocTest<ShareTabBloc, ShareTabState>(
      'updates access level for user',
      build: () => bloc,
      act: (bloc) => bloc.add(
        ShareTabEvent.updateUserAccessLevel(
          email: email,
          accessLevel: ShareAccessLevel.fullAccess,
        ),
      ),
      wait: const Duration(milliseconds: 100),
      expect: () => [
        // First state: initial empty state
        isA<ShareTabState>().having(
          (s) => s.updateAccessLevelResult,
          'updateAccessLevelResult',
          isNull,
        ),
        // Second state: after initialization (currentUser, shareLink set, updateAccessLevelResult still null)
        isA<ShareTabState>()
            .having(
              (s) => s.updateAccessLevelResult,
              'updateAccessLevelResult',
              isNull,
            )
            .having((s) => s.currentUser, 'currentUser', isNotNull)
            .having((s) => s.shareLink, 'shareLink', isNotEmpty),
        // Third state: updateAccessLevelResult is Success and users updated
        isA<ShareTabState>()
            .having(
              (s) => s.updateAccessLevelResult,
              'updateAccessLevelResult',
              isNotNull,
            )
            .having(
              (s) => s.users.firstWhere((u) => u.email == email).accessLevel,
              'vivian accessLevel',
              ShareAccessLevel.fullAccess,
            ),
      ],
    );

    final guestEmail = 'guest@appflowy.io';
    blocTest<ShareTabBloc, ShareTabState>(
      'turns user into member',
      build: () => bloc,
      act: (bloc) => bloc
        ..add(
          ShareTabEvent.inviteUsers(
            emails: [guestEmail],
            accessLevel: ShareAccessLevel.readOnly,
          ),
        )
        ..add(
          ShareTabEvent.turnIntoMember(
            email: guestEmail,
            name: 'Guest',
          ),
        ),
      wait: const Duration(milliseconds: 100),
      expect: () => [
        // First state: initial empty state
        isA<ShareTabState>().having(
          (s) => s.shareResult,
          'shareResult',
          isNull,
        ),
        // Second state: after initialization
        isA<ShareTabState>()
            .having((s) => s.shareResult, 'shareResult', isNull)
            .having((s) => s.currentUser, 'currentUser', isNotNull)
            .having((s) => s.shareLink, 'shareLink', isNotEmpty),
        // Third state: shareResult is Success and users updated
        isA<ShareTabState>()
            .having(
              (s) => s.shareResult,
              'shareResult',
              isNotNull,
            )
            .having(
              (s) => s.users.any((u) => u.email == guestEmail),
              'users contains guest@appflowy.io',
              isTrue,
            ),
        // Fourth state: turnIntoMemberResult is Success and users updated
        isA<ShareTabState>()
            .having(
              (s) => s.turnIntoMemberResult,
              'turnIntoMemberResult',
              isNotNull,
            )
            .having(
              (s) => s.users.firstWhere((u) => u.email == guestEmail).role,
              'guest@appflowy.io role',
              ShareRole.member,
            ),
      ],
    );
  });
}
