import 'package:appflowy/env/cloud_env.dart';
import 'package:appflowy/features/mension_person/presentation/mention_menu.dart';
import 'package:appflowy/features/mension_person/presentation/widgets/person/person_profile_card.dart';
import 'package:appflowy/features/mension_person/presentation/widgets/person/person_tooltip.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/mention/mention_block.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/mention/mention_person_block.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pbenum.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../../shared/constants.dart';
import '../../../shared/util.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Mention tests', () {
    testWidgets('insert a person', (tester) async {
      await tester.initializeAppFlowy(
        cloudType: AuthenticatorType.appflowyCloudSelfHost,
      );
      await tester.tapGoogleLoginInButton();
      await tester.expectToSeeHomePageWithGetStartedPage();
      await tester.createNewPageInSpace(
        spaceName: Constants.generalSpaceName,
        layout: ViewLayoutPB.Document,
        pageName: 'Document',
      );

      await tester.editor.tapLineOfEditorAt(0);
      await tester.editor.showAtMenu();
      expect(find.byType(MentionMenu), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(PersonToolTip), findsWidgets);

      /// insert a person
      await tester.tapButton(
        find.byType(PersonToolTip).first,
        pumpAndSettle: false,
      );

      /// check for the node
      final node = tester.editor.getNodeAtPath([0]);
      final delta = node.delta!;
      final insert = (delta.first as TextInsert).text;
      final attributes = delta.first.attributes;
      expect(insert, MentionBlockKeys.mentionChar);
      final mention =
          attributes?[MentionBlockKeys.mention] as Map<String, dynamic>;
      expect(mention[MentionBlockKeys.type], MentionType.person.name);
      expect(mention[MentionBlockKeys.personId], isNotNull);
      expect(mention[MentionBlockKeys.personName], isNotNull);
      expect(mention[MentionBlockKeys.pageId], isNotNull);

      await tester.hoverOnWidget(
        find.byType(MentionPersonBlock),
        onHover: () async {
          /// the profile card should be shown
          expect(find.byType(PersonProfileCard), findsOneWidget);
        },
      );
    });
  });
}
