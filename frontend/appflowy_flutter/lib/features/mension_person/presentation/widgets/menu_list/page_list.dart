import 'package:appflowy/features/mension_person/presentation/mention_menu.dart';
import 'package:appflowy/features/mension_person/presentation/mention_menu_service.dart';
import 'package:appflowy/plugins/document/application/prelude.dart';
import 'package:appflowy/plugins/inline_actions/handlers/child_page.dart';
import 'package:appflowy/plugins/inline_actions/handlers/inline_page_reference.dart';
import 'package:flutter/material.dart';
import 'package:appflowy/features/mension_person/data/models/mention_menu_item.dart';
import 'package:appflowy/features/mension_person/logic/mention_bloc.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy/workspace/presentation/command_palette/widgets/search_icon.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:universal_platform/universal_platform.dart';

import '../item_auto_scroll_tag.dart';
import '../more_results_item.dart';

extension MentionMenuItemPageWidgetsExtension on MentionMenuItem {
  Widget buildPageItem(BuildContext context) {
    final theme = AppFlowyTheme.of(context),
        mentionBloc = context.read<MentionBloc>(),
        mentionState = mentionBloc.state,
        item = this;
    if (item is PageMentionMenuItem) {
      final view = item.view;
      return MentionMenuItemAutoScrollTag(
        id: view.id,
        child: AFTextMenuItem(
          selected:
              mentionState.selectedId == view.id && UniversalPlatform.isDesktop,
          leading: SizedBox(
            width: 24,
            child: Center(child: view.buildIcon(context)),
          ),
          title: view.nameOrDefault,
          backgroundColor: context.mentionItemBGColor,
          onTap: () => mentionBloc.add(MentionEvent.executeItem(this)),
        ),
      );
    } else if (item is MoreResultMentionMenuItem) {
      return MoreResultsItem(
        num: mentionState.filterViews.length - 4,
        onTap: () => mentionBloc.add(MentionEvent.executeItem(this)),
        id: item.id,
      );
    } else if (item is AddViewMenuItem) {
      return MentionMenuItemAutoScrollTag(
        id: id,
        child: AFTextMenuItem(
          selected:
              mentionState.selectedId == id && UniversalPlatform.isDesktop,
          title: LocaleKeys.inlineActions_createPage
              .tr(args: [mentionState.query]),
          maxTitleLine: 1,
          leading: SizedBox.square(
            dimension: 24,
            child: Center(
              child: FlowySvg(
                FlowySvgs.mention_create_page_m,
                color: theme.iconColorScheme.primary,
                size: const Size.square(20.0),
              ),
            ),
          ),
          backgroundColor: context.mentionItemBGColor,
          onTap: () => mentionBloc.add(MentionEvent.executeItem(this)),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> onPageItemExecuted(BuildContext context) async {
    final item = this;
    if (item.type != MentionMenuType.page) return;
    if (item is PageMentionMenuItem) {
      await _onPageSelected(item.view, context);
    } else if (item is MoreResultMentionMenuItem) {
      _showMore(context);
    } else if (item is AddViewMenuItem) {
      await _onPageCreate(context);
    }
  }

  Future<void> _onPageSelected(ViewPB view, BuildContext context) async {
    final mentionInfo = context.read<MentionMenuServiceInfo>(),
        editorState = mentionInfo.editorState,
        query = context.read<MentionBloc>().state.query;
    final selection = editorState.selection;
    if (selection == null || !selection.isCollapsed) return;

    final node = editorState.getNodeAtPath(selection.end.path);
    final delta = node?.delta;
    if (node == null || delta == null) return;

    final range = mentionInfo.textRange(query);
    await editorState.insertPageLinkRef(view, (range.start, range.end));
    mentionInfo.onDismiss.call(null);
  }

  Future<void> _onPageCreate(BuildContext context) async {
    final mentionInfo = context.read<MentionMenuServiceInfo>(),
        editorState = mentionInfo.editorState,
        query = context.read<MentionBloc>().state.query,
        documentBloc = context.read<DocumentBloc?>();

    if (query.isEmpty || documentBloc == null) return;
    final selection = editorState.selection;
    if (selection == null || !selection.isCollapsed) return;

    final node = editorState.getNodeAtPath(selection.end.path);
    final delta = node?.delta;
    if (node == null || delta == null) return;

    final range = mentionInfo.textRange(query);
    await editorState.insertChildPage(
      documentBloc.documentId,
      (range.start, range.end),
      query,
    );
    mentionInfo.onDismiss.call(editorState.selection);
  }

  void _showMore(BuildContext context) {
    final mentionBloc = context.read<MentionBloc>();
    final pages = mentionBloc.state.filterViews;
    mentionBloc.add(
      MentionEvent.showMorePages(UniversalPlatform.isMobile ? '' : pages[4].id),
    );
  }
}
