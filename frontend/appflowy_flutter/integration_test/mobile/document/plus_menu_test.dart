import 'dart:async';

import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/inline_actions/mobile_inline_actions_handler.dart';
import 'package:appflowy/mobile/presentation/inline_actions/mobile_inline_actions_menu_group.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/mention/mention_page_block.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/plugins.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../shared/util.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('document plus menu:', () {
    testWidgets('add the toggle heading blocks via plus menu', (tester) async {
      await tester.launchInAnonymousMode();
      await tester.createNewDocumentOnMobile('toggle heading blocks');

      final editorState = tester.editor.getCurrentEditorState();

      unawaited(
        editorState.updateSelectionWithReason(
          Selection.collapsed(Position(path: [0])),
          reason: SelectionUpdateReason.uiEvent,
        ),
      );
      await tester.pumpAndSettle();

      await tester.openPlusMenuAndClickButton(
        LocaleKeys.editor_toggleHeading1ShortForm.tr(),
      );

      final block1 = editorState.getNodeAtPath([0])!;
      expect(block1.type, equals(ToggleListBlockKeys.type));
      expect(block1.attributes[ToggleListBlockKeys.level], equals(1));

      await tester.testTextInput.receiveAction(TextInputAction.newline);
      await tester.pumpAndSettle();

      await tester.openPlusMenuAndClickButton(
        LocaleKeys.editor_toggleHeading2ShortForm.tr(),
      );

      final block2 = editorState.getNodeAtPath([1])!;
      expect(block2.type, equals(ToggleListBlockKeys.type));
      expect(block2.attributes[ToggleListBlockKeys.level], equals(2));

      await tester.testTextInput.receiveAction(TextInputAction.newline);
      await tester.pumpAndSettle();
    });

    const title = 'Test Plus Menu';
    testWidgets('show plus menu', (tester) async {
      await tester.launchInAnonymousMode();
      await tester.createPageAndShowPlusMenu(title);
      final menuWidget = find.byType(MobileInlineActionsHandler);
      expect(menuWidget, findsOneWidget);
    });

    testWidgets('search by plus menu', (tester) async {
      await tester.launchInAnonymousMode();
      await tester.createPageAndShowPlusMenu(title);
      const searchText = gettingStarted;
      await tester.ime.insertText(searchText);
      final actionWidgets = find.byType(MobileInlineActionsWidget);
      expect(actionWidgets, findsNWidgets(2));
    });

    testWidgets('tap plus menu', (tester) async {
      await tester.launchInAnonymousMode();
      await tester.createPageAndShowPlusMenu(title);
      const searchText = gettingStarted;
      await tester.ime.insertText(searchText);
      final actionWidgets = find.byType(MobileInlineActionsWidget);
      await tester.tap(actionWidgets.last);
      expect(find.byType(MentionPageBlock), findsOneWidget);
    });
  });
}
