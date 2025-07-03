import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/bottom_sheet_buttons.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/show_mobile_bottom_sheet.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class EditDescriptionBottomSheet extends StatefulWidget {
  const EditDescriptionBottomSheet(
    this.context, {
    this.description,
    required this.onSubmitted,
    super.key,
  });
  final BuildContext context;
  final String? description;
  final void Function(String) onSubmitted;
  @override
  State<EditDescriptionBottomSheet> createState() =>
      _EditDescriptionBottomSheetState();
}

class _EditDescriptionBottomSheetState
    extends State<EditDescriptionBottomSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController textEditingController =
      TextEditingController(text: widget.description);

  @override
  void dispose() {
    textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context), spacing = theme.spacing;
    void submitDescription() {
      if (_formKey.currentState!.validate()) {
        final value = textEditingController.text;
        if (value.isEmpty) return;
        widget.onSubmitted.call(value);
        widget.context.pop();
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
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
              onDone: submitDescription,
            );
          },
        ),
        SizedBox(
          height: 132,
          child: Form(
            key: _formKey,
            child: AFTextField(
              autoFocus: true,
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r"\n")),
              ],
              size: AFTextFieldSize.m,
              controller: textEditingController,
              maxLines: null,
              expands: true,
              maxLength: 190,
              counterText: '',
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              onEditingComplete: submitDescription,
            ),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: textEditingController,
          builder: (_, __, ___) {
            final text = textEditingController.text.trim();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                VSpace(spacing.xs),
                Text(
                  LocaleKeys.settings_profilePage_limitCharacters
                      .tr(args: ['${text.length} / 190']),
                  style: theme.textStyle.body
                      .standard(color: theme.textColorScheme.tertiary),
                ),
              ],
            );
          },
        ),
        VSpace(theme.spacing.xl),
      ],
    );
  }
}
