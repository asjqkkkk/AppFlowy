import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/bottom_sheet_buttons.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/show_mobile_bottom_sheet.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EditUsernameBottomSheet extends StatefulWidget {
  const EditUsernameBottomSheet(
    this.context, {
    this.userName,
    required this.onSubmitted,
    super.key,
  });
  final BuildContext context;
  final String? userName;
  final void Function(String) onSubmitted;
  @override
  State<EditUsernameBottomSheet> createState() =>
      _EditUsernameBottomSheetState();
}

class _EditUsernameBottomSheetState extends State<EditUsernameBottomSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController textEditingController =
      TextEditingController(text: widget.userName);

  @override
  void dispose() {
    textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    void submitUserName() {
      if (_formKey.currentState!.validate()) {
        final value = textEditingController.text;
        if (value.isEmpty) return;
        widget.onSubmitted.call(value);
        widget.context.pop();
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        BottomSheetHeader(
          showBackButton: false,
          showDoneButton: true,
          showCloseButton: true,
          showRemoveButton: false,
          title: LocaleKeys.settings_profilePage_displayName.tr(),
          doneButtonBuilder: (context) {
            return BottomSheetDoneButton(
              text: LocaleKeys.button_save.tr(),
              onDone: submitUserName,
            );
          },
        ),
        Form(
          key: _formKey,
          child: AFTextField(
            autoFocus: true,
            controller: textEditingController,
            keyboardType: TextInputType.text,
            maxLength: 72,
            counterText: '',
            validator: (controller) {
              final value = controller.text.trim();
              if (value.isEmpty) {
                return (
                  true,
                  LocaleKeys.settings_mobile_usernameEmptyError.tr()
                );
              }
              return (false, '');
            },
            onEditingComplete: submitUserName,
          ),
        ),
        VSpace(theme.spacing.xl),
      ],
    );
  }
}
