import 'package:appflowy/features/mension_person/data/models/mention_menu_item.dart';
import 'package:appflowy/features/mension_person/logic/mention_bloc.dart';
import 'package:appflowy/features/mension_person/presentation/mention_menu.dart';
import 'package:appflowy/features/mension_person/presentation/mention_menu_service.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/inline_actions/handlers/date_reference.dart';
import 'package:appflowy/plugins/inline_actions/handlers/reminder_reference.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'item_visibility_detector.dart';

class DateReminderList extends StatelessWidget {
  const DateReminderList({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context),
        spacing = theme.spacing,
        mentionBloc = context.read<MentionBloc>(),
        mentionState = mentionBloc.state,
        itemMap = mentionState.itemMap,
        items = itemMap.getItems(MentionMenuType.dateAndReminder);

    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.all(spacing.m),
      child: AFMenuSection(
        title: LocaleKeys.document_mentionMenu_dateAndReminder.tr(),
        children: List.generate(items.length, (index) {
          final item = items[index];
          return MentionMenuItenVisibilityDetector(
            id: item.id,
            child: AFTextMenuItem(
              title: item.id,
              selected: context.read<MentionBloc>().state.selectedId == item.id,
              onTap: () => mentionBloc.add(MentionEvent.executeItem(item)),
              backgroundColor: context.mentionItemBGColor,
            ),
          );
        }),
      ),
    );
  }
}

extension DateReminderItemExtension on MentionMenuItem {
  Future<void> onDateOrReminderItemExecuted(BuildContext context) async {
    final item = this;
    if (item is! DateReminderMentionMenuItem) return;
    if (item.id == LocaleKeys.document_mentionMenu_dateToday.tr()) {
      await _onDateInsert(context, DateTime.now());
    } else if (item.id == LocaleKeys.document_mentionMenu_dateTomorrow.tr()) {
      await _onDateInsert(
        context,
        DateTime.now().add(const Duration(days: 1)),
      );
    } else if (item.id == LocaleKeys.document_mentionMenu_dateYesterday.tr()) {
      await _onDateInsert(
        context,
        DateTime.now().subtract(const Duration(days: 1)),
      );
    } else if (item.id ==
        LocaleKeys.document_mentionMenu_reminderTomorrow9Am.tr()) {
      await _onReminderInsert(
        context,
        DateTime.now().add(const Duration(days: 1, hours: 9)),
        true,
      );
    } else if (item.id == LocaleKeys.document_mentionMenu_reminder1Week.tr()) {
      await _onReminderInsert(
        context,
        DateTime.now().add(const Duration(days: 7)),
        false,
      );
    }
  }

  Future<void> _onDateInsert(
    BuildContext context,
    DateTime date,
  ) async {
    final mentionInfo = context.read<MentionMenuServiceInfo>(),
        editorState = mentionInfo.editorState,
        query = context.read<MentionBloc>().state.query;
    final selection = editorState.selection;
    if (selection == null || !selection.isCollapsed) return;

    final node = editorState.getNodeAtPath(selection.end.path);
    final delta = node?.delta;
    if (node == null || delta == null) return;
    final range = mentionInfo.textRange(query);

    _onDismiss(mentionInfo);
    await editorState.insertDateReference(date, range.start, range.end);
  }

  Future<void> _onReminderInsert(
    BuildContext context,
    DateTime date,
    bool includeTime,
  ) async {
    final mentionInfo = context.read<MentionMenuServiceInfo>(),
        editorState = mentionInfo.editorState,
        query = context.read<MentionBloc>().state.query;
    final selection = editorState.selection;
    if (selection == null || !selection.isCollapsed) return;

    final node = editorState.getNodeAtPath(selection.end.path);
    final delta = node?.delta;
    if (node == null || delta == null) return;

    final range = mentionInfo.textRange(query);
    _onDismiss(mentionInfo);
    await editorState.insertReminderReference(
      context,
      date,
      range.start,
      range.end,
      includeTime: includeTime,
    );
  }

  void _onDismiss(MentionMenuServiceInfo info) {
    info.onDismiss.call();
  }
}
