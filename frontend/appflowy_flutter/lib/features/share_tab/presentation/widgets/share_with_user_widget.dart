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
    final shareTabBloc = context.read<ShareTabBloc>(),
        shareTabState = shareTabBloc.state,
        availableEmails = shareTabState.users.map((e) => e.email).toSet();

    final Widget child = Row(
      children: [
        Expanded(
          child: InviteTextField(
            textController: effectiveController,
            controller: inviteController,
            readOnly: widget.disabled,
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
            isEmailInvited: (email) => availableEmails.contains(email),
            persons: shareTabState.persons
                .where((e) => !availableEmails.contains(e.email))
                .toList(),
            filterPersons: (v) {
              final query = v.toLowerCase();
              final availablePersons = shareTabState.persons
                  .where((e) => !availableEmails.contains(e.email))
                  .toList();
              if (query.isEmpty) return availablePersons;
              return availablePersons
                  .where(
                    (e) =>
                        e.name.toLowerCase().contains(query) ||
                        e.email.toLowerCase().contains(query),
                  )
                  .toList();
            },
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
}
