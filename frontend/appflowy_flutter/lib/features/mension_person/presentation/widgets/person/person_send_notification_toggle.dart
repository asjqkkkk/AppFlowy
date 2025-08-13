import 'package:appflowy/features/mension_person/logic/mention_bloc.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/workspace/presentation/widgets/toggle/toggle.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SendNotificationToggle extends StatefulWidget {
  const SendNotificationToggle({super.key});

  @override
  State<SendNotificationToggle> createState() => _SendNotificationToggleState();
}

class _SendNotificationToggleState extends State<SendNotificationToggle> {
  Duration animationDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          animationDuration = const Duration(milliseconds: 150);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    final bloc = context.read<MentionBloc>(), state = bloc.state;

    return Row(
      children: [
        Text(
          LocaleKeys.document_mentionMenu_sendNotification.tr(),
          style: theme.textStyle.caption
              .standard(color: theme.textColorScheme.secondary)
              .copyWith(letterSpacing: 0.1),
        ),
        SizedBox(width: 4),
        Toggle(
          value: state.sendNotification,
          style: ToggleStyle(width: 34, height: 18, thumbRadius: 17),
          padding: EdgeInsets.zero,
          duration: animationDuration,
          inactiveBackgroundColor: theme.fillColorScheme.secondary,
          onChanged: (v) {
            bloc.add(MentionEvent.toggleSendNotification());
          },
        ),
      ],
    );
  }
}
