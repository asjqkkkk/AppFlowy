import 'package:appflowy/features/mension_person/presentation/mention_menu.dart';
import 'package:appflowy/features/mension_person/presentation/mention_menu_service.dart';
import 'package:appflowy/features/workspace/logic/workspace_bloc.dart';
import 'package:appflowy/plugins/document/application/document_bloc.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/mention/mention_block.dart';
import 'package:appflowy_backend/protobuf/flowy-user/workspace.pbenum.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:appflowy/features/mension_person/data/models/person.dart';
import 'package:appflowy/features/mension_person/data/models/mention_menu_item.dart';
import 'package:appflowy/features/mension_person/logic/mention_bloc.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:universal_platform/universal_platform.dart';
import '../invite/person_list_invite_item.dart';
import '../item_visibility_detector.dart';
import '../more_results_item.dart';
import 'person_send_notification_toggle.dart';
import 'person_tooltip.dart';

class PersonList extends StatelessWidget {
  const PersonList({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<MentionBloc>(),
        itemMap = bloc.state.itemMap,
        items = itemMap.getItems(MentionMenuType.person),
        userWorkspaceBloc = context.read<UserWorkspaceBloc?>(),
        theme = AppFlowyTheme.of(context),
        spacing = theme.spacing;

    if (userWorkspaceBloc == null) return const SizedBox.shrink();
    final workspaceType =
        userWorkspaceBloc.state.currentWorkspace?.workspaceType;

    if (workspaceType == WorkspaceTypePB.Vault || items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.all(spacing.m),
      child: AFMenuSection(
        title: LocaleKeys.document_mentionMenu_people.tr(),
        titleTrailing: SendNotificationToggle(),
        children: List.generate(
          items.length,
          (index) => items[index].buildPersonItem(context),
        ),
      ),
    );
  }
}

extension PersonListEditorStateExtension on EditorState {
  Future<void> insertPerson(
    Person person,
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
          personId: person.id,
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
        userWorkspaceBloc = context.read<UserWorkspaceBloc?>();
    final userState = userWorkspaceBloc?.userProfile, item = this;
    if (item is PersonMentionMenuItem) {
      final person = item.person;
      final isCurrentUser = person.email == userState?.email;
      final selected =
          state.selectedId == person.id && UniversalPlatform.isDesktop;
      return MentionMenuItenVisibilityDetector(
        id: person.id,
        child: PersonToolTip(
          isMyself: isCurrentUser,
          selected: selected,
          person: person,
          sendNotification: state.sendNotification,
          key: ValueKey('${person.id}-$selected'),
          child: AFTextMenuItem(
            leading: AFAvatar(
              url: person.avatarUrl,
              size: AFAvatarSize.s,
              name: person.name,
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
        id: persons[4].id,
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
      final persons =
          mentionBloc.state.itemMap.getItems(MentionMenuType.person);
      final lastIndex = persons.indexWhere((e) => e.id == item.id);
      mentionBloc.add(
        MentionEvent.showMorePersons(
          UniversalPlatform.isMobile ? '' : persons[lastIndex].id,
        ),
      );
    }
  }

  Future<void> _onPersonSelected(
    Person person,
    BuildContext context,
  ) async {
    final mentionInfo = context.read<MentionMenuServiceInfo>(),
        editorState = mentionInfo.editorState,
        mentionBloc = context.read<MentionBloc>(),
        documentBloc = context.read<DocumentBloc>(),
        mentionState = mentionBloc.state,
        query = mentionState.query;
    final selection = editorState.selection;
    if (selection == null || !selection.isCollapsed) return;

    final node = editorState.getNodeAtPath(selection.end.path);
    final delta = node?.delta;
    if (node == null || delta == null) return;
    mentionBloc.add(
      MentionEvent.mentionPerson(
        documentId: documentBloc.documentId,
        personId: person.id,
        blockId: node.id,
      ),
    );
    final range = mentionInfo.textRange(query);
    mentionInfo.onDismiss.call();
    await editorState.insertPerson(
      person,
      documentBloc.documentId,
      range,
      mentionState.sendNotification,
      selection,
    );
  }
}
