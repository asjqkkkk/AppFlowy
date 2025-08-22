import 'package:appflowy/features/share_tab/data/models/share_role.dart';
import 'package:appflowy/features/share_tab/data/models/share_section_type.dart';
import 'package:appflowy/features/share_tab/data/models/shared_user.dart';
import 'package:appflowy/features/share_tab/logic/share_tab_bloc.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/widget/flowy_tooltip.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'invite_text_field.dart';

class ShareWithUserWidget extends StatefulWidget {
  const ShareWithUserWidget({
    super.key,
    required this.onInvite,
    this.controller,
    this.disabled = false,
    this.showAccessLevelWidget = true,
    this.tooltip,
  });

  final TextEditingController? controller;
  final ValueChanged<EmailsWithAccessLevel> onInvite;
  final bool disabled;
  final bool showAccessLevelWidget;
  final String? tooltip;

  @override
  State<ShareWithUserWidget> createState() => _ShareWithUserWidgetState();
}

class _ShareWithUserWidgetState extends State<ShareWithUserWidget> {
  late final TextEditingController effectiveController;
  final InviteController inviteController = InviteController();
  bool isButtonEnabled = false;
  EmailsWithAccessLevel? emailsWithAccessLevel;

  @override
  void initState() {
    super.initState();

    effectiveController = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      effectiveController.dispose();
    }
    inviteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    final shareTabBloc = context.watch<ShareTabBloc>();

    final displayingUsers = buildDisplayingUsers(shareTabBloc, '');
    final remainingEmails = buildRemainingEmails(
      shareTabBloc,
      displayingUsers.map((e) => e.email).toSet(),
    );

    final Widget child = Row(
      children: [
        Expanded(
          child: InviteTextField(
            textController: effectiveController,
            controller: inviteController,
            readOnly: widget.disabled,
            displayingUsers: displayingUsers,
            showAccessLevelWidget: widget.showAccessLevelWidget,
            onDataChanged: (data) {
              final enableButton = data.emails.isNotEmpty;
              if (isButtonEnabled != enableButton) {
                setState(() {
                  isButtonEnabled = enableButton;
                });
              }
              emailsWithAccessLevel = data;
            },
            isEmailInvited: (email) => remainingEmails.contains(email),
            filterUsers: (v) => buildDisplayingUsers(shareTabBloc, v),
          ),
        ),
        HSpace(theme.spacing.s),
        AFFilledTextButton.primary(
          text: LocaleKeys.shareTab_invite.tr(),
          disabled: !isButtonEnabled,
          onTap: () {
            if (emailsWithAccessLevel == null) return;
            widget.onInvite(emailsWithAccessLevel!);
            inviteController.onInvite();
          },
        ),
      ],
    );

    if (widget.disabled) {
      return FlowyTooltip(
        message:
            widget.tooltip ?? LocaleKeys.shareTab_onlyFullAccessCanInvite.tr(),
        child: IgnorePointer(
          child: child,
        ),
      );
    }

    return child;
  }

  List<SharedUser> buildDisplayingUsers(ShareTabBloc bloc, String query) {
    final state = bloc.state,
        sectionType = state.sectionType,
        isPrivateOrShared = sectionType == SharedSectionType.private ||
            sectionType == SharedSectionType.shared,
        currentUserEmail = state.currentUser?.email,
        invitedUsers = state.users;
    Set<SharedUser> availableUsers = invitedUsers.toSet();
    final emails = availableUsers.map((e) => e.email).toSet();

    /// If the page is private or shared, include all users here
    /// 1. for the invited persons, we can change their access level at once
    /// 2. for the uninvited persons, we can invite them with specific access level
    if (isPrivateOrShared) {
      availableUsers.addAll(
        state.persons
            .where((p) => !emails.contains(p.email))
            .map((p) => p.toShareUser()),
      );
    } else {
      /// if the page is public, all the member should not be invited again,
      /// because they already have full access
      availableUsers =
          availableUsers.where((u) => u.role == ShareRole.guest).toSet();
    }

    /// you cannot invite yourself
    availableUsers.removeWhere((u) => u.email == currentUserEmail);
    if (query.isEmpty) return availableUsers.toList();

    /// filter persons by the query text
    return availableUsers
        .where(
          (e) =>
              e.name.toLowerCase().contains(query) ||
              e.email.toLowerCase().contains(query),
        )
        .toList();
  }

  Set<String> buildRemainingEmails(
    ShareTabBloc bloc,
    Set<String> currentEmails,
  ) {
    final state = bloc.state;
    final currentUserEmail = state.currentUser?.email;
    return <String>{
      if (currentUserEmail != null) currentUserEmail,
      ...state.users
          .map((e) => e.email)
          .where((e) => !currentEmails.contains(e)),
      ...state.persons
          .map((e) => e.email)
          .where((e) => !currentEmails.contains(e)),
    };
  }
}
