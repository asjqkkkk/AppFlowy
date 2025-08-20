import 'package:appflowy/features/share_tab/data/repositories/local_share_with_user_repository_impl.dart';
import 'package:appflowy/features/share_tab/logic/share_tab_bloc.dart';
import 'package:appflowy/features/share_tab/presentation/widgets/share_with_user_widget.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../../../integration_test/shared/util.dart';
import '../../../widget_test_wrapper.dart';

void main() {
  group('share_with_user_widget.dart: ', () {
    testWidgets('shows input and button, triggers callback on valid email',
        (WidgetTester tester) async {
      List<String>? invited;
      await tester.pumpWidget(
        WidgetTestWrapper(
          child: Provider(
            create: (_) => ShareTabBloc(
              repository: LocalShareWithUserRepositoryImpl(),
              pageId: 'pageId',
            ),
            child: ShareWithUserWidget(
              onInvite: (v) => invited = v.emails,
              showAccessLevelWidget: false,
            ),
          ),
        ),
      );
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(LocaleKeys.shareTab_invite.tr()), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'test@user.com');
      await tester.pumpAndSettle();
      await tester.tapButton(find.byType(AFMenuItem));
      await tester.tapButton(find.text(LocaleKeys.shareTab_invite.tr()));
      expect(invited, isNotNull);
      expect(invited, contains('test@user.com'));
    });
  });
}
