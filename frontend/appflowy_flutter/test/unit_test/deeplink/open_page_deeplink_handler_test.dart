import 'package:appflowy/startup/tasks/deeplink/open_page_deeplink_handler.dart';
import 'package:appflowy/workspace/presentation/home/menu/sidebar/workspace/workspace_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OpenPageDeepLinkHandler', () {
    late OpenPageDeepLinkHandler handler;

    setUp(() {
      handler = OpenPageDeepLinkHandler();
      openWorkspaceNotifier.value = null;
    });

    tearDown(() {
      openWorkspaceNotifier.value = null;
    });

    group('canHandle', () {
      test('returns true for valid open-page URLs with all required parameters',
          () {
        final uri = Uri.parse(
          'appflowy-flutter://open-page?workspace_id=6555e07f-c149-4cb8-aabd-dafd856bbb52&view_id=5e10d34e-dfa8-41bb-b545-10b37ca051f3&email=lucas.xu@appflowy.io',
        );

        final result = handler.canHandle(uri);

        expect(result, isTrue);
      });

      test('returns false for non-open-page host', () {
        final uri = Uri.parse(
          'appflowy-flutter://other-host?workspace_id=6555e07f-c149-4cb8-aabd-dafd856bbb52&view_id=5e10d34e-dfa8-41bb-b545-10b37ca051f3&email=lucas.xu@appflowy.io',
        );

        final result = handler.canHandle(uri);

        expect(result, isFalse);
      });
    });

    group('handle', () {
      test('successfully handles valid URI and sets workspace notifier',
          () async {
        const workspaceId = '6555e07f-c149-4cb8-aabd-dafd856bbb52';
        const viewId = '5e10d34e-dfa8-41bb-b545-10b37ca051f3';
        const email = 'lucas.xu@appflowy.io';

        final uri = Uri.parse(
          'appflowy-flutter://open-page?workspace_id=$workspaceId&view_id=$viewId&email=$email',
        );

        final result = await handler.handle(
          uri: uri,
          onStateChange: (handler, state) {},
        );

        expect(result.isSuccess, isTrue);
        expect(openWorkspaceNotifier.value, isNotNull);
        expect(openWorkspaceNotifier.value!.workspaceId, equals(workspaceId));
        expect(openWorkspaceNotifier.value!.email, equals(email));
        expect(openWorkspaceNotifier.value!.initialViewId, equals(viewId));
      });

      test('overwrites previous workspace notifier value', () async {
        // Set initial value
        openWorkspaceNotifier.value = WorkspaceNotifyValue(
          workspaceId: 'old-workspace',
          email: 'old@email.com',
          initialViewId: 'old-view',
        );

        const newWorkspaceId = '6555e07f-c149-4cb8-aabd-dafd856bbb52';
        const newViewId = '5e10d34e-dfa8-41bb-b545-10b37ca051f3';
        const newEmail = 'lucas.xu@appflowy.io';

        final uri = Uri.parse(
          'appflowy-flutter://open-page?workspace_id=$newWorkspaceId&view_id=$newViewId&email=$newEmail',
        );

        final result = await handler.handle(
          uri: uri,
          onStateChange: (handler, state) {},
        );

        expect(result.isSuccess, isTrue);
        expect(openWorkspaceNotifier.value, isNotNull);
        expect(
          openWorkspaceNotifier.value!.workspaceId,
          equals(newWorkspaceId),
        );
        expect(openWorkspaceNotifier.value!.email, equals(newEmail));
        expect(openWorkspaceNotifier.value!.initialViewId, equals(newViewId));
      });
    });
  });
}
