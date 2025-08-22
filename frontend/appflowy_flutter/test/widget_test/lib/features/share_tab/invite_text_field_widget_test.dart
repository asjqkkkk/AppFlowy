import 'package:appflowy/features/share_tab/data/models/shared_user.dart';
import 'package:appflowy/features/share_tab/presentation/widgets/invite_text_field.dart';
import 'package:appflowy/features/share_tab/presentation/widgets/invite_text_field_popover.dart';
import 'package:appflowy/features/share_tab/presentation/widgets/inviting_item.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../integration_test/shared/util.dart';
import '../../../widget_test_wrapper.dart';

void main() {
  group('invite_text_field_widget_test.dart: ', () {
    testWidgets('shows input and button, triggers callback on valid email',
        (WidgetTester tester) async {
      final controller = TextEditingController();
      bool enableSendInvitation = false;
      final displayingUsers = _buildDisplayingUsers('');
      final remainingEmails =
          _buildRemainingEmails(displayingUsers.map((e) => e.email).toSet());
      await tester.runAsync(
        () async {
          await tester.pumpWidget(
            WidgetTestWrapper(
              child: SizedBox(
                width: 900,
                height: 100,
                child: InviteTextField(
                  showAccessLevelWidget: false,
                  textController: controller,
                  readOnly: false,
                  displayingUsers:
                      _workspacePersons.map((e) => e.toShareUser()).toList(),
                  filterUsers: (v) => _buildDisplayingUsers(v),
                  onDataChanged: (data) {
                    enableSendInvitation = data.emails.isNotEmpty;
                  },
                  isEmailInvited: (email) => remainingEmails.contains(email),
                ),
              ),
            ),
          );

          expect(find.byType(TextField), findsOneWidget);
          expect(enableSendInvitation, false);

          /// typing an existing email
          await tester.enterText(
            find.byType(TextField),
            'john.doe@appflowy.io',
          );
          await tester.pumpAndSettle();
          await tester.tapButton(
            find.descendant(
              of: find.byType(AFMenuItem),
              matching: find.text('john.doe@appflowy.io'),
            ),
          );
          expect(find.byType(InvitingItem), findsNothing);
          expect(enableSendInvitation, false);

          /// typing a new email
          await tester.enterText(find.byType(TextField), 'morn@gmail.com');
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(
              of: find.byType(AFMenuItem),
              matching: find.text('morn@gmail.com'),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(InvitingItem), findsOneWidget);
          expect(enableSendInvitation, true);

          /// check the menu displaying logic
          await tester.enterText(find.byType(TextField), '');
          expect(find.byType(InviteTextFieldPopover), findsOneWidget);
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), 'morn@gmail.com');
          await tester.pumpAndSettle();
          expect(find.byType(InviteTextFieldPopover), findsNothing);
          await tester.pumpAndSettle();

          /// remove current email
          await tester.enterText(find.byType(TextField), ' ');
          await tester.simulateKeyEvent(LogicalKeyboardKey.backspace);
          await tester.simulateKeyEvent(LogicalKeyboardKey.backspace);
          expect(find.byType(InvitingItem), findsNothing);
          expect(enableSendInvitation, false);

          /// insert emails by comma separate
          final emails = 'a@gmail.com, b@gmail.com, c@gmail.com';
          await tester.enterText(
            find.byType(TextField),
            emails,
          );
          await tester.pumpAndSettle();
          expect(find.byType(InvitingItem), findsNWidgets(3));
          await tester.enterText(
            find.byType(TextField),
            '$emails, d@gmail.com',
          );
          await tester.pumpAndSettle();
          expect(find.byType(InvitingItem), findsNWidgets(4));
        },
      );
    });
  });
}

List<SharedUser> _buildDisplayingUsers(String query) {
  final availableUsers = _sharedUsers
      .where((u) => u.role == MentionablePersonTypePB.WorkspaceGuest)
      .map((e) => e.toShareUser())
      .toSet();

  if (query.isEmpty) return availableUsers.toList();
  return availableUsers
      .where(
        (e) =>
            e.name.toLowerCase().contains(query) ||
            e.email.toLowerCase().contains(query),
      )
      .toList();
}

Set<String> _buildRemainingEmails(Set<String> currentEmails) {
  final remainingEmails = <String>{};
  for (final person in _sharedUsers) {
    if (!currentEmails.contains(person.email)) {
      remainingEmails.add(person.email);
    }
  }
  return remainingEmails;
}

final List<MentionablePersonPB> _workspacePersons = [
  MentionablePersonPB(
    uuid: '1',
    name: 'John Doe',
    role: MentionablePersonTypePB.WorkspaceMember,
    email: 'john.doe@appflowy.io',
  ),
  MentionablePersonPB(
    uuid: '2',
    name: 'Jane Smith',
    role: MentionablePersonTypePB.WorkspaceMember,
    email: 'jane.smith@appflowy.io',
  ),
  MentionablePersonPB(
    uuid: '3',
    name: 'Bob Johnson',
    role: MentionablePersonTypePB.WorkspaceGuest,
    email: 'bob.johnson@appflowy.io',
  ),
  MentionablePersonPB(
    uuid: '4',
    name: 'Alice Brown',
    role: MentionablePersonTypePB.WorkspaceMember,
    email: 'alice.brown@appflowy.io',
  ),
  MentionablePersonPB(
    uuid: '5',
    name: 'Charlie Black',
    role: MentionablePersonTypePB.WorkspaceGuest,
    email: 'charlie.black@appflowy.io',
  ),
];

final List<MentionablePersonPB> _sharedUsers = [
  ..._workspacePersons,
  MentionablePersonPB(
    uuid: '6',
    name: 'David Wilson',
    role: MentionablePersonTypePB.WorkspaceGuest,
    email: 'david.wilson@appflowy.io',
  ),
  MentionablePersonPB(
    uuid: '7',
    name: 'Eve White',
    role: MentionablePersonTypePB.WorkspaceMember,
    email: 'eve.white@appflowy.io',
  ),
];
