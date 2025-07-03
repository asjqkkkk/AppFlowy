import 'package:flutter/material.dart';

class TextEditControllerProvider extends StatefulWidget {

  const TextEditControllerProvider({
    super.key,
    required this.builder,
    this.initialText,
  });

  final TextEditControllerProviderBuilder builder;
  final String? initialText;

  @override
  State<TextEditControllerProvider> createState() =>
      _TextEditControllerProviderState();
}

class _TextEditControllerProviderState
    extends State<TextEditControllerProvider> {
  late final TextEditingController controller =
      TextEditingController(text: widget.initialText  ?? '');

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder.call(context, controller);
  }
}

typedef TextEditControllerProviderBuilder = Widget Function(
  BuildContext context,
  TextEditingController controller,
);
