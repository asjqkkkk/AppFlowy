import 'package:appflowy/features/mension_person/data/models/mention_menu_item.dart';
import 'package:appflowy/features/mension_person/logic/mention_bloc.dart';
import 'package:appflowy/features/mension_person/presentation/mention_menu.dart';
import 'package:appflowy/features/mension_person/presentation/mention_menu_service.dart';
import 'package:appflowy/features/mension_person/presentation/widgets/mention_menu_scroller.dart';
import 'package:appflowy/features/workspace/workspace.dart';
import 'package:appflowy/plugins/document/application/document_bloc.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/mention/mention_block.dart';
import 'package:appflowy/shared/custom_image_cache_manager.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:universal_platform/universal_platform.dart';

import '../invite/person_list_invite_item.dart';
import '../item_auto_scroll_tag.dart';
import '../more_results_item.dart';
import 'person_tooltip.dart';

extension PersonListEditorStateExtension on EditorState {
  Future<void> insertPerson(
    MentionablePersonPB person,
    String pageId,
    TextRange range,
    bool sendNotification,
    Selection? selection,
  ) async {
    final mSelection = selection ?? this.selection;
    if (mSelection == null || !mSelection.isCollapsed) return;

    final node = getNodeAtPath(mSelection.start.path);
    final delta = node?.delta;
    if (node == null || delta == null) return;

    final transaction = this.transaction
      ..replaceText(
        node,
        range.start,
        range.end,
        MentionBlockKeys.mentionChar,
        attributes: MentionBlockKeys.buildMentionPersonAttributes(
          personId: person.uuid,
          personName: person.name,
          pageId: pageId,
          blockId: node.id,
        ),
      );

    await apply(transaction);
  }
}

extension MentionMenuItemPersonWidgetsExtension on MentionMenuItem {
  Widget buildPersonItem(BuildContext context) {
    final bloc = context.read<MentionBloc>(),
        state = bloc.state,
        userWorkspaceBloc = context.read<UserWorkspaceBloc?>(),
        scrollControllerProvier = context.read<AutoScrollControllerProvider>();
    final userState = userWorkspaceBloc?.userProfile, item = this;
    if (item is PersonMentionMenuItem) {
      final person = item.person;
      final isCurrentUser = person.email == userState?.email;
      final selected =
          state.selectedId == person.uuid && UniversalPlatform.isDesktop;
      return MentionMenuItemAutoScrollTag(
        id: person.uuid,
        child: PersonToolTip(
          isMyself: isCurrentUser,
          selected: selected,
          person: person,
          scrollController: scrollControllerProvier.controller,
          sendNotification: state.sendNotification,
          key: ValueKey('${person.uuid}$selected'),
          child: AFTextMenuItem(
            leading: AFAvatar(
              url: person.avatarUrl,
              size: AFAvatarSize.s,
              name: person.name,
              email: person.email,
              cacheManager: CustomAvatarCacheManager(),
            ),
            selected: selected,
            title: person.name,
            subtitle: person.email,
            backgroundColor: context.mentionItemBGColor,
            onTap: () => bloc.add(ExecuteItem(item)),
          ),
        ),
      );
    } else if (item is MoreResultMentionMenuItem) {
      final persons = state.persons;
      return MoreResultsItem(
        num: persons.length - 4,
        onTap: () => bloc.add(MentionEvent.executeItem(this)),
        id: item.id,
      );
    } else if (item is AddPersonMentionMenuItem) {
      return PersonListInviteItem();
    }
    return const SizedBox.shrink();
  }

  Future<void> onPersonItemExecuted(BuildContext context) async {
    final item = this;
    if (item.type != MentionMenuType.person) return;
    if (item is PersonMentionMenuItem) {
      await _onPersonSelected(item.person, context);
    } else if (item is MoreResultMentionMenuItem) {
      final mentionBloc = context.read<MentionBloc>();
      final persons = mentionBloc.state.persons;
      mentionBloc.add(
        MentionEvent.showMorePersons(
          UniversalPlatform.isMobile ? '' : persons[4].uuid,
        ),
      );
    }
  }

  Future<void> _onPersonSelected(
    MentionablePersonPB person,
    BuildContext context,
  ) async {
    final mentionInfo = context.read<MentionMenuServiceInfo>(),
        editorState = mentionInfo.editorState,
        mentionBloc = context.read<MentionBloc>(),
        documentBloc = context.read<DocumentBloc>(),
        mentionState = mentionBloc.state,
        query = mentionState.query;
    // if the database view id is not null, it means this page is in a database view
    // otherwise, it means this page is a normal page
    final ancestorId = documentBloc.databaseViewId ?? documentBloc.documentId;
    final selection = editorState.selection;
    if (selection == null || !selection.isCollapsed) return;

    final node = editorState.getNodeAtPath(selection.end.path);
    final delta = node?.delta;
    if (node == null || delta == null) return;
    mentionBloc.add(
      MentionEvent.mentionPerson(
        documentId: documentBloc.documentId,
        personId: person.uuid,
        ancestorId: ancestorId,
        blockId: node.id,
      ),
    );
    final range = mentionInfo.textRange(query);
    await editorState.insertPerson(
      person,
      documentBloc.documentId,
      range,
      mentionState.sendNotification,
      selection,
    );
    mentionInfo.onDismiss.call(editorState.selection);
  }
}
