import 'package:appflowy/features/mension_person/presentation/mention_menu.dart';
import 'package:appflowy/mobile/presentation/inline_actions/mobile_inline_actions_menu_group.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/mention/mention_page_block.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../shared/util.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const title = 'Test At Menu';

  group('at menu', () {
    testWidgets('show at menu', (tester) async {
      await tester.launchInAnonymousMode();
      await tester.createPageAndShowAtMenu(title);
      final menuWidget = find.byType(MentionMenu);
      expect(menuWidget, findsOneWidget);
    });

    testWidgets('search by at menu', (tester) async {
      await tester.launchInAnonymousMode();
      await tester.createPageAndShowAtMenu(title);
      await tester.pumpAndSettle();
      await tester.ime.insertText(gettingStarted);
      await tester.pumpAndSettle();
      final actionWidgets = find.byType(AFTextMenuItem);
      expect(actionWidgets, findsOneWidget);
    });

    testWidgets('tap at menu', (tester) async {
      await tester.launchInAnonymousMode();
      await tester.createPageAndShowAtMenu(title);
      await tester.pumpAndSettle();
      await tester.ime.insertText(gettingStarted);
      await tester.pumpAndSettle();
      final actionWidgets = find.byType(AFTextMenuItem);
      await tester.tap(actionWidgets.last);
      await tester.pumpAndSettle();
      expect(find.byType(MentionPageBlock), findsOneWidget);
    });

    testWidgets('create subpage with at menu', (tester) async {
      await tester.launchInAnonymousMode();
      await tester.createNewDocumentOnMobile(title);
      await tester.editor.tapLineOfEditorAt(0);
      const subpageName = 'Subpage';
      await tester.ime.insertText('[[$subpageName');
      await tester.pumpAndSettle();
      final actionWidgets = find.byType(MobileInlineActionsWidget);
      await tester.tapButton(actionWidgets.first);
      final firstNode =
          tester.editor.getCurrentEditorState().getNodeAtPath([0]);
      assert(firstNode != null);
      expect(firstNode!.delta?.toPlainText().contains('['), false);
    });
  });
}
