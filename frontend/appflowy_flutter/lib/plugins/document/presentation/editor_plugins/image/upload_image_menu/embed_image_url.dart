import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:universal_platform/universal_platform.dart';

class EmbedImageUrl extends StatefulWidget {
  const EmbedImageUrl({
    super.key,
    required this.onSubmit,
  });

  final void Function(String url) onSubmit;

  @override
  State<EmbedImageUrl> createState() => _EmbedImageUrlState();
}

class _EmbedImageUrlState extends State<EmbedImageUrl> {
  final textController = TextEditingController();
  final focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (UniversalPlatform.isDesktop) {
        focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    textController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    final isMobile = UniversalPlatform.isMobile;

    return Column(
      spacing: theme.spacing.m,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AFTextField(
          size: isMobile ? AFTextFieldSize.l : AFTextFieldSize.m,
          controller: textController,
          focusNode: focusNode,
          hintText: LocaleKeys.document_imageBlock_embedLink_placeholder.tr(),
          onSubmitted: widget.onSubmit,
        ),
        ValueListenableBuilder(
          valueListenable: textController,
          builder: (context, value, child) {
            return AFFilledTextButton.primary(
              text: LocaleKeys.document_imageBlock_embedLink_label.tr(),
              size: isMobile ? AFButtonSize.l : AFButtonSize.m,
              disabled: value.text.isEmpty,
              onTap: () => widget.onSubmit(textController.text),
            );
          },
        ),
      ],
    );
  }
}
