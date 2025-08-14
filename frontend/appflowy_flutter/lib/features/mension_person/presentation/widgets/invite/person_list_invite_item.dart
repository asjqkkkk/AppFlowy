import 'package:appflowy/features/mension_person/data/models/models.dart';
import 'package:appflowy/features/mension_person/logic/mention_bloc.dart';
import 'package:appflowy/features/mension_person/presentation/mention_menu.dart';
import 'package:appflowy/features/mension_person/presentation/mention_menu_service.dart';
import 'package:appflowy/features/mension_person/presentation/widgets/item_auto_scroll_tag.dart';
import 'package:appflowy/features/mension_person/presentation/widgets/person/person_list.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/document/application/document_bloc.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:universal_platform/universal_platform.dart';

import 'invite_menu.dart';
import '../mobile/mobile_invite_menu.dart';

class PersonListInviteItem extends StatelessWidget {
  const PersonListInviteItem({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<MentionBloc>().state, query = state.query;
    final id = AddPersonMentionMenuItem.addPersonId;
    final displayQuery = query.isEmpty ? '' : ' "$query"';
    return BlocListener<MentionBloc, MentionState>(
      listener: (context, state) {
        final item = state.executedItem;
        if (item is! AddPersonMentionMenuItem) return;
        invitePerson(context);
      },
      listenWhen: (previous, current) =>
          previous.executedItem?.id != current.executedItem?.id,
      child: MentionMenuItemAutoScrollTag(
        id: id,
        child: AFTextMenuItem(
          selected: state.selectedId == id,
          leading: FlowySvg(
            FlowySvgs.mention_menu_invite_icon_m,
            size: const Size(24, 20),
          ),
          title: LocaleKeys.document_mentionMenu_add.tr(args: [displayQuery]),
          backgroundColor: context.mentionItemBGColor,
          onTap: () => UniversalPlatform.isMobile
              ? showMobileInviteMenu(context)
              : invitePerson(context),
        ),
      ),
    );
  }

  void invitePerson(BuildContext context) {
    final serviceInfo = context.read<MentionMenuServiceInfo>(),
        documentBloc = context.read<DocumentBloc?>();
    final mentionBloc = context.read<MentionBloc>(),
        mentionState = mentionBloc.state,
        query = mentionState.query;

    serviceInfo.onMenuReplace.call(
      MentionMenuBuilderInfo(
        builder: (service, lrbt) => service.buildMultiBlocProvider(
          (_) => Provider.value(
            value: serviceInfo,
            child: InviteMenu(
              query: query,
              info: InviteInfo(email: query),
              onInfoChanged: (v) => serviceInfo.editorState.onInviteInfoApply(
                inviteInfo: v,
                serviceInfo: serviceInfo,
                documentBloc: documentBloc,
                mentionBloc: mentionBloc,
              ),
            ),
          ),
        ),
        menuSize: Size(400, 400),
      ),
    );
  }
}

extension PersonInviteEditorStateExtension on EditorState {
  Future<void> onInviteInfoApply({
    required InviteInfo inviteInfo,
    required MentionMenuServiceInfo serviceInfo,
    DocumentBloc? documentBloc,
    Selection? selection,
    required MentionBloc mentionBloc,
  }) async {
    final mSelection = selection ?? this.selection;
    if (mSelection == null || !mSelection.isCollapsed || documentBloc == null) {
      return;
    }
    final mentionState = mentionBloc.state, query = mentionState.query;
    final node = getNodeAtPath(mSelection.end.path);
    final delta = node?.delta;
    if (node == null || delta == null) return;
    final range = serviceInfo.textRange(query);
    final result = await mentionBloc.repository.invitePerson(
      workspaceId: mentionBloc.workspaceId,
      info: inviteInfo,
    );
    await result.fold((person) async {
      // mentionBloc.add(
      //   MentionEvent.mentionPerson(
      //     documentId: documentBloc.documentId,
      //     personId: person.id,
      //     blockId: node.id,
      //   ),
      // );

      await insertPerson(
        person,
        documentBloc.documentId,
        range,
        mentionState.sendNotification,
        mSelection,
      );
      serviceInfo.onDismiss.call(this.selection);
      final isContact = person.role == MentionablePersonTypePB.Contact;
      if (isContact) {
        showToastNotification(
          message: LocaleKeys.document_mentionMenu_addContactToast
              .tr(args: [person.name]),
        );
      } else {
        showToastNotification(
          message: LocaleKeys.document_mentionMenu_inviteEmailSent.tr(),
        );
      }
    }, (error) {
      showToastNotification(
        message: error.msg,
        type: ToastificationType.error,
      );
    });
  }
}
