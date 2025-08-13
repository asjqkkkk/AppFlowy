import 'package:appflowy/features/mension_person/presentation/mention_menu.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/mention/mention_block.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../shared/util.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> preparePage(WidgetTester tester, {String? pageName}) async {
    await tester.initializeAppFlowy();
    await tester.tapAnonymousSignInButton();
    await tester.createNewPageWithNameUnderParent(name: pageName);
    await tester.editor.tapLineOfEditorAt(0);
    await tester.editor.showAtMenu();
    await tester.pumpAndSettle();
    expect(find.byType(MentionMenu), findsOneWidget);
  }

  group('Mention menu test', () {
    testWidgets('Insert a subpage', (tester) async {
      await preparePage(tester);

      /// insert a page reference, search for [Ge]tting Started
      await tester.simulateKeyEvent(LogicalKeyboardKey.keyG);
      await tester.simulateKeyEvent(LogicalKeyboardKey.keyE);
      await tester.pumpAndSettle();
      await tester.simulateKeyEvent(LogicalKeyboardKey.enter);

      /// check for the node
      final node = tester.editor.getNodeAtPath([0]);
      final delta = node.delta!;
      final insert = (delta.first as TextInsert).text;
      final attributes = delta.first.attributes;
      expect(insert, MentionBlockKeys.mentionChar);
      final mention =
          attributes?[MentionBlockKeys.mention] as Map<String, dynamic>;
      expect(mention[MentionBlockKeys.type], MentionType.page.name);
      expect(mention[MentionBlockKeys.pageId], isNotNull);
    });

    testWidgets('Create a subpage', (tester) async {
      await preparePage(tester);

      /// no "Create a subpage" item
      expect(find.byFlowySvg(FlowySvgs.mention_create_page_m), findsNothing);

      /// create a subpage, named [page]
      await tester.simulateKeyEvent(LogicalKeyboardKey.keyP);
      await tester.simulateKeyEvent(LogicalKeyboardKey.keyA);
      await tester.simulateKeyEvent(LogicalKeyboardKey.keyG);
      await tester.simulateKeyEvent(LogicalKeyboardKey.keyE);
      await tester.pumpAndSettle();
      expect(find.byFlowySvg(FlowySvgs.mention_create_page_m), findsOneWidget);
      await tester.simulateKeyEvent(LogicalKeyboardKey.enter);

      /// check for the node
      final node = tester.editor.getNodeAtPath([0]);
      final delta = node.delta!;
      final insert = (delta.first as TextInsert).text;
      final attributes = delta.first.attributes;
      expect(insert, MentionBlockKeys.mentionChar);
      final mention =
          attributes?[MentionBlockKeys.mention] as Map<String, dynamic>;
      expect(mention[MentionBlockKeys.type], MentionType.childPage.name);
      expect(mention[MentionBlockKeys.pageId], isNotNull);
    });

    testWidgets('Insert a date or reminder', (tester) async {
      await preparePage(tester);

      /// insert a date or reminder
      await tester.simulateKeyEvent(LogicalKeyboardKey.numpad1);
      await tester.simulateKeyEvent(LogicalKeyboardKey.space);
      await tester.simulateKeyEvent(LogicalKeyboardKey.keyW);
      await tester.pumpAndSettle();
      await tester.simulateKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.simulateKeyEvent(LogicalKeyboardKey.enter);

      /// check for the node
      final node = tester.editor.getNodeAtPath([0]);
      final delta = node.delta!;
      final insert = (delta.first as TextInsert).text;
      final attributes = delta.first.attributes;
      expect(insert, MentionBlockKeys.mentionChar);
      final mention =
          attributes?[MentionBlockKeys.mention] as Map<String, dynamic>;
      expect(mention[MentionBlockKeys.type], MentionType.date.name);
      expect(mention[MentionBlockKeys.date], isNotNull);
    });
  });
}
