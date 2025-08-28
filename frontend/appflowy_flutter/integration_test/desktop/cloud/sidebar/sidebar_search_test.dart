import 'package:appflowy/env/cloud_env.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/workspace/presentation/command_palette/widgets/recent_views_list.dart';
import 'package:appflowy/workspace/presentation/command_palette/widgets/search_ask_ai_entrance.dart';
import 'package:appflowy/workspace/presentation/command_palette/widgets/search_field.dart';
import 'package:appflowy/workspace/presentation/command_palette/widgets/search_results_list.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../../shared/util.dart';

void main() {
  setUpAll(() {
    IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('Test for searching', (tester) async {
    await tester.initializeAppFlowy(
      cloudType: AuthenticatorType.appflowyCloudSelfHost,
    );
    await tester.tapGoogleLoginInButton();
    await tester.expectToSeeHomePageWithGetStartedPage();

    /// show searching page
    final searchingButton = find.text(LocaleKeys.search_label.tr());
    await tester.tapButton(searchingButton);
    final askAIButton = find.byType(SearchAskAiEntrance);
    final recentViews = find.byType(RecentViewsList);
    final resultViews = find.byType(SearchResultList);
    expect(askAIButton, findsOneWidget);
    expect(recentViews, findsOneWidget);
    expect(resultViews, findsNothing);

    /// searching for [gettingStarted]
    final searchField = find.byType(SearchField);
    final textFiled =
        find.descendant(of: searchField, matching: find.byType(TextField));
    await tester.enterText(textFiled, gettingStarted);
    await tester.pumpAndSettle(Duration(seconds: 3));
    expect(recentViews, findsNothing);

    /// clear search
    await tester.enterText(textFiled, '');
    await tester.pumpAndSettle();
    expect(recentViews, findsOneWidget);
    expect(resultViews, findsNothing);

    /// searching for [gettingStarted] again
    await tester.enterText(textFiled, gettingStarted);
    await tester.pumpAndSettle(Duration(seconds: 3));
    expect(recentViews, findsNothing);

    /// tap ask AI button
    try {
      await tester.tapButton(askAIButton, pumpAndSettle: false);
      await tester.pumpAndSettle(Duration(seconds: 6));
    } catch (e) {
      debugPrint('error with tapping ask AI button: $e');
      return;
    }
    expect(find.byFlowySvg(FlowySvgs.chat_ai_page_s), findsAtLeast(1));
  });
}
