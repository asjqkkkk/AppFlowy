import 'dart:async';
import 'dart:math';

import 'package:appflowy/core/config/kv.dart';
import 'package:appflowy/core/config/kv_keys.dart';
import 'package:appflowy/plugins/document/application/document_bloc.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/menu/menu_extension.dart';
import 'package:appflowy/plugins/inline_actions/inline_actions_menu.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/user/application/reminder/reminder_bloc.dart';
import 'package:appflowy/workspace/application/user/user_workspace_bloc.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'mention_menu.dart';

abstract class MentionMenuService implements InlineActionsMenuService {
  MultiBlocProvider buildMultiBlocProvider(WidgetBuilder builder);

  bool _isShowing = false;

  bool get isShowing => _isShowing;

  @override
  Future<void> show() async {
    _isShowing = true;
  }

  @override
  void dismiss() {
    _isShowing = false;
  }
}

class DesktopMentionMenuService extends MentionMenuService {
  DesktopMentionMenuService({
    required this.context,
    required this.editorState,
    required this.workspaceBloc,
    required this.documentBloc,
    required this.reminderBloc,
    this.startCharAmount = 1,
  });

  final BuildContext context;
  final EditorState editorState;
  final UserWorkspaceBloc workspaceBloc;
  final DocumentBloc documentBloc;
  final ReminderBloc reminderBloc;
  final int startCharAmount;

  OverlayEntry? _menuEntry;

  @override
  void dismiss() {
    if (_menuEntry != null) {
      editorState.service.keyboardService?.enable();
      editorState.service.scrollService?.disable();
      keepEditorFocusNotifier.decrease();

      super.dismiss();
    }
    _menuEntry?.remove();
    _menuEntry = null;
  }

  void dismissByOtherMenu(Selection? selection) {
    final newSelection = selection ?? editorState.selection;
    dismiss();
    if (newSelection != null) {
      editorState.selection = null;
      editorState.service.keyboardService?.closeKeyboard();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        editorState.service.keyboardService?.enableKeyBoard(newSelection);
        editorState.selection = newSelection;
      });
    }
  }

  @override
  Future<void> show() async {
    await super.show();
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      final sendNotification = await getIt<KeyValueStorage>()
              .getBool(KVKeys.atMenuSendNotification) ??
          false;
      _show(
        MentionMenuBuilderInfo(
          builder: (service, ltrb) => _buildMentionMenu(ltrb, sendNotification),
          menuSize: Size(400, 300),
        ),
      );
      completer.complete();
    });
    return completer.future;
  }

  @override
  InlineActionsMenuStyle get style => throw UnimplementedError();

  void _show(MentionMenuBuilderInfo builderInfo) {
    dismiss();

    final menuPosition = editorState.calculateMenuOffset(
      menuSize: builderInfo.menuSize,
      menuOffset: Offset.zero,
    );
    if (menuPosition == null) return;
    final ltrb = menuPosition.ltrb;

    final editorSize = editorState.renderBox!.size;
    _menuEntry = OverlayEntry(
      builder: (context) => Material(
        color: Colors.transparent,
        child: SizedBox(
          height: editorSize.height,
          width: editorSize.width,
          // GestureDetector handles clicks outside of the context menu,
          // to dismiss the context menu.
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: dismiss,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ltrb.buildPositioned(
                  child: builderInfo.builder.call(this, ltrb),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final editorService = editorState.service;
    editorService.keyboardService?.disable(showCursor: true);
    Overlay.of(context).insert(_menuEntry!);
    editorService.keyboardService?.enable();
  }

  Widget _buildMentionMenu(LTRB ltrb, bool sendNotification) {
    final editorHeight = editorState.renderBox!.size.height;
    final menuHeight = editorHeight <= 700 ? 300.0 : 400.0;
    final top =
        ltrb.top ?? (max(editorHeight - (ltrb.bottom ?? 0.0) - menuHeight, 0));
    return buildMultiBlocProvider(
      (_) => Provider(
        create: (_) => MentionMenuServiceInfo(
          onDismiss: (s) => dismissByOtherMenu(s),
          startCharAmount: startCharAmount,
          startOffset: editorState.selection?.endIndex ?? 0,
          editorState: editorState,
          top: top,
          onMenuReplace: (info) {
            keepEditorFocusNotifier.increase();
            _show(info);
          },
        ),
        child: MentionMenu(
          sendNotification: sendNotification,
          maxHeight: menuHeight,
        ),
      ),
    );
  }

  @override
  MultiBlocProvider buildMultiBlocProvider(WidgetBuilder builder) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: workspaceBloc),
        BlocProvider.value(value: documentBloc),
        BlocProvider.value(value: reminderBloc),
      ],
      child: BlocBuilder<UserWorkspaceBloc, UserWorkspaceState>(
        builder: (context, __) => builder.call(context),
      ),
    );
  }
}

typedef MentionMenuBuilder = Widget Function(
  MentionMenuService service,
  LTRB ltrb,
);

class MentionMenuBuilderInfo {
  MentionMenuBuilderInfo({
    required this.builder,
    required this.menuSize,
  });

  final MentionMenuBuilder builder;
  final Size menuSize;
}

class MentionMenuServiceInfo {
  MentionMenuServiceInfo({
    required this.onDismiss,
    required this.startCharAmount,
    required this.startOffset,
    required this.editorState,
    required this.top,
    required this.onMenuReplace,
  });

  final ValueChanged<Selection?> onDismiss;
  final int startCharAmount;
  final int startOffset;
  final EditorState editorState;
  final double top;
  final ValueChanged<MentionMenuBuilderInfo> onMenuReplace;

  TextRange textRange(String queryText) => TextRange(
        start: startOffset - startCharAmount,
        end: queryText.length + startCharAmount,
      );
}
