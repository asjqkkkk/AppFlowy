import 'dart:collection';

import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:easy_localization/easy_localization.dart';

abstract class MentionMenuItem {
  MentionMenuItem({required this.id, required this.type});

  final String id;
  final MentionMenuType type;
}

class PersonMentionMenuItem extends MentionMenuItem {
  PersonMentionMenuItem({required this.person})
      : super(
          id: person.uuid,
          type: MentionMenuType.person,
        );

  final MentionablePersonPB person;
}

class AddPersonMentionMenuItem extends MentionMenuItem {
  AddPersonMentionMenuItem({required this.query})
      : super(id: addPersonId, type: MentionMenuType.person);

  final String query;

  static final addPersonId =
      LocaleKeys.document_mentionMenu_add.tr(args: ['add person']);
}

class MoreResultMentionMenuItem extends MentionMenuItem {
  MoreResultMentionMenuItem({
    required super.id,
    required super.type,
  });

  static final showMorePagesId =
      LocaleKeys.document_mentionMenu_moreResults.tr(args: ['show more pages']);

  static final showMorePersonsId = LocaleKeys.document_mentionMenu_moreResults
      .tr(args: ['show more persons']);
}

class PageMentionMenuItem extends MentionMenuItem {
  PageMentionMenuItem({required this.view})
      : super(
          id: view.id,
          type: MentionMenuType.page,
        );

  final ViewPB view;
}

class AddViewMenuItem extends MentionMenuItem {
  AddViewMenuItem({required this.query})
      : super(id: addPageId, type: MentionMenuType.page);

  final String query;

  static final addPageId =
      LocaleKeys.inlineActions_createPage.tr(args: ['add page']);
}

class DateReminderMentionMenuItem extends MentionMenuItem {
  DateReminderMentionMenuItem({required super.id})
      : super(type: MentionMenuType.dateAndReminder);
}

enum MentionMenuType {
  person,
  page,
  dateAndReminder,
}

class MentionItemMap {
  MentionItemMap._(
    Map<MentionMenuType, UnmodifiableListView<MentionMenuItem>> map,
  ) : _map = UnmodifiableMapView(map);

  MentionItemMap.empty()
      : _map = UnmodifiableMapView({
          MentionMenuType.person: UnmodifiableListView([]),
          MentionMenuType.page: UnmodifiableListView([]),
          MentionMenuType.dateAndReminder:
              UnmodifiableListView(dateReminderMentionMenuItems),
        });

  final UnmodifiableMapView<MentionMenuType,
      UnmodifiableListView<MentionMenuItem>> _map;

  MentionItemMap addItems(List<MentionMenuItem> items) {
    final copyMap = Map.of(_map);
    for (final item in items) {
      final oldItems = List<MentionMenuItem>.of(copyMap[item.type] ?? []);
      oldItems.add(item);
      copyMap[item.type] = UnmodifiableListView(oldItems);
    }
    return MentionItemMap._(copyMap);
  }

  MentionItemMap clearItems(List<MentionMenuType> types) {
    final copyMap = Map.of(_map);
    for (final type in types) {
      copyMap[type] = UnmodifiableListView([]);
    }
    return MentionItemMap._(copyMap);
  }

  List<MentionMenuItem> getItems(MentionMenuType type) =>
      _map[type] ?? UnmodifiableListView([]);

  List<MentionMenuItem> get items =>
      _map.values.expand((items) => items).toList();
}

final dateReminderMentionMenuItems = UnmodifiableListView<MentionMenuItem>(
  [
    LocaleKeys.document_mentionMenu_dateToday.tr(),
    LocaleKeys.document_mentionMenu_dateTomorrow.tr(),
    LocaleKeys.document_mentionMenu_dateYesterday.tr(),
    LocaleKeys.document_mentionMenu_reminderTomorrow9Am.tr(),
    LocaleKeys.document_mentionMenu_reminder1Week.tr(),
  ].map((title) => DateReminderMentionMenuItem(id: title)),
);
