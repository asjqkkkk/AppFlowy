import 'package:appflowy/core/config/kv.dart';
import 'package:appflowy/core/config/kv_keys.dart';

import 'package:appflowy/features/mension_person/data/models/mention_menu_item.dart';
import 'package:appflowy/features/mension_person/data/repositories/rust_mention_repository.dart';
import 'package:appflowy/features/mension_person/logic/mention_bloc.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/workspace/application/recent/recent_views_bloc.dart';
import 'package:appflowy/features/workspace/workspace.dart';
import 'package:appflowy_backend/protobuf/flowy-user/workspace.pbenum.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:universal_platform/universal_platform.dart';
import 'mention_menu_service.dart';
import 'widgets/menu_list/date_reminder_list.dart';
import 'widgets/item_auto_scroll_tag.dart';
import 'widgets/mention_menu_scroller.dart';
import 'widgets/mention_menu_shortcuts.dart';
import 'widgets/menu_list/page_list.dart';
import 'widgets/person/person_list.dart';
import 'widgets/person/person_send_notification_toggle.dart';

typedef MentionChildBuilder = Widget Function(
  BuildContext context,
  Widget child,
);

class MentionMenu extends StatelessWidget {
  const MentionMenu({
    super.key,
    this.query = '',
    this.width = 400,
    this.maxHeight = 400,
    this.builder,
    required this.sendNotification,
  });
  final double width;
  final double maxHeight;
  final String query;
  final bool sendNotification;
  final MentionChildBuilder? builder;

  @override
  Widget build(BuildContext context) {
    final workspaceId =
        context.read<UserWorkspaceBloc>().state.currentWorkspace?.workspaceId ??
            '';
    final mentionInfo = context.read<MentionMenuServiceInfo>();

    return GestureDetector(
      /// avoid the menu being dismissed when tapping inside it
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => MentionBloc(
              repository: RustMentionRepository(),
              workspaceId: workspaceId,
              query: query,
              sendNotification: sendNotification,
            )..add(MentionEvent.init()),
          ),
          BlocProvider(
            create: (context) =>
                RecentViewsBloc()..add(const RecentViewsEvent.initial()),
          ),
        ],
        child: BlocBuilder<MentionBloc, MentionState>(
          builder: (context, state) {
            return BlocBuilder<RecentViewsBloc, RecentViewsState>(
              builder: (context, recentState) {
                final child = MentionMenuScroller(
                  builder: (_, controller) {
                    return MultiBlocListener(
                      listeners: [
                        BlocListener<MentionBloc, MentionState>(
                          listener: (context, state) {
                            if (!controller.hasClients || !context.mounted) {
                              return;
                            }
                            controller.jumpTo(0);
                          },
                          listenWhen: (previous, current) =>
                              previous.query != current.query,
                        ),
                        BlocListener<MentionBloc, MentionState>(
                          listener: (context, state) {
                            getIt<KeyValueStorage>().setBool(
                              KVKeys.atMenuSendNotification,
                              state.sendNotification,
                            );
                          },
                          listenWhen: (previous, current) =>
                              previous.sendNotification !=
                              current.sendNotification,
                        ),
                      ],
                      child: MentionMenuShortcuts(
                        scrollController: controller,
                        initialSearchText: state.query,
                        editorState: mentionInfo.editorState,
                        child: buildMenu(context, controller),
                      ),
                    );
                  },
                );
                return builder?.call(context, child) ?? child;
              },
            );
          },
        ),
      ),
    );
  }

  Widget buildMenu(BuildContext context, ScrollController controller) {
    final theme = AppFlowyTheme.of(context),
        state = context.read<MentionBloc>().state,
        itemMap = state.itemMap,
        hasPersons = itemMap.getItems(MentionMenuType.person).isNotEmpty,
        hasPages = itemMap.getItems(MentionMenuType.page).isNotEmpty,
        hasDateOrReminders =
            itemMap.getItems(MentionMenuType.dateAndReminder).isNotEmpty;

    return BlocListener<MentionBloc, MentionState>(
      listener: (context, state) => onItemExecuted(context, state),
      listenWhen: (previous, current) =>
          previous.executedItem?.id != current.executedItem?.id,
      child: BlocBuilder<MentionBloc, MentionState>(
        builder: (context, state) {
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Container(
              decoration: BoxDecoration(
                color: theme.surfaceColorScheme.primary,
                borderRadius: BorderRadius.circular(theme.borderRadius.l),
                border: Border.all(
                  color: theme.borderColorScheme.primary,
                ),
                boxShadow: theme.shadow.medium,
              ),
              width: width,
              padding: EdgeInsets.zero,
              child: FlowyScrollbar(
                controller: controller,
                child: ListView(
                  controller: controller,
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  children: [
                    ..._buildPersonList(context),
                    if (hasPersons && (hasPages || hasDateOrReminders))
                      AFDivider(),
                    ..._buildPageList(context),
                    if (hasDateOrReminders && hasPages) AFDivider(),
                    ..._buildDateAndReminders(context),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildPersonList(BuildContext context) {
    final bloc = context.read<MentionBloc>(),
        itemMap = bloc.state.itemMap,
        items = itemMap.getItems(MentionMenuType.person),
        userWorkspaceBloc = context.read<UserWorkspaceBloc?>(),
        theme = AppFlowyTheme.of(context),
        spacing = theme.spacing;
    if (userWorkspaceBloc == null) return [];
    final workspaceType =
        userWorkspaceBloc.state.currentWorkspace?.workspaceType;

    if (workspaceType == WorkspaceTypePB.Vault || items.isEmpty) {
      return [];
    }
    return [
      VSpace(spacing.m),
      _buildTitle(
        title: LocaleKeys.document_mentionMenu_people.tr(),
        titleTrailing: SendNotificationToggle(),
        context: context,
      ),
      ...List.generate(
        items.length,
        (index) => items[index].buildPersonItem(context),
      ),
      VSpace(spacing.m),
    ];
  }

  List<Widget> _buildPageList(BuildContext context) {
    final theme = AppFlowyTheme.of(context),
        spacing = theme.spacing,
        mentionBloc = context.read<MentionBloc>(),
        mentionState = mentionBloc.state;
    final pages = mentionState.itemMap.getItems(MentionMenuType.page);
    if (pages.isEmpty) return [];
    return [
      VSpace(spacing.m),
      _buildTitle(
        title: LocaleKeys.document_mentionMenu_pages.tr(),
        context: context,
      ),
      ...List.generate(
        pages.length,
        (index) => pages[index].buildPageItem(context),
      ),
      VSpace(spacing.m),
    ];
  }

  List<Widget> _buildDateAndReminders(BuildContext context) {
    final theme = AppFlowyTheme.of(context),
        spacing = theme.spacing,
        mentionBloc = context.read<MentionBloc>(),
        mentionState = mentionBloc.state,
        itemMap = mentionState.itemMap,
        items = itemMap.getItems(MentionMenuType.dateAndReminder);

    if (items.isEmpty) return [];
    return [
      VSpace(spacing.m),
      _buildTitle(
        title: LocaleKeys.document_mentionMenu_dateAndReminder.tr(),
        context: context,
      ),
      ...List.generate(items.length, (index) {
        final item = items[index];
        return MentionMenuItemAutoScrollTag(
          id: item.id,
          child: AFTextMenuItem(
            title: item.id,
            selected: mentionState.selectedId == item.id &&
                UniversalPlatform.isDesktop,
            onTap: () => mentionBloc.add(MentionEvent.executeItem(item)),
            backgroundColor: context.mentionItemBGColor,
          ),
        );
      }),
      VSpace(spacing.m),
    ];
  }

  Widget _buildTitle({
    required String title,
    required BuildContext context,
    Widget? titleTrailing,
  }) {
    final theme = AppFlowyTheme.of(context), spacing = theme.spacing;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.m, vertical: spacing.s),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textStyle.caption.enhanced(
                color: theme.textColorScheme.tertiary,
              ),
            ),
          ),
          if (titleTrailing != null) titleTrailing,
        ],
      ),
    );
  }

  void onItemExecuted(
    BuildContext context,
    MentionState state,
  ) {
    final item = state.executedItem;
    if (item == null) return;
    item.onPersonItemExecuted(context);
    item.onPageItemExecuted(context);
    item.onDateOrReminderItemExecuted(context);
  }
}

extension MentionMenuItemBackgroundColor on BuildContext {
  Color mentionItemBGColor(
    BuildContext context,
    bool isHovering,
    bool selected,
    bool disabled,
  ) {
    final theme = AppFlowyTheme.of(this);
    return isHovering || selected
        ? theme.fillColorScheme.contentHover
        : theme.fillColorScheme.content;
  }
}
