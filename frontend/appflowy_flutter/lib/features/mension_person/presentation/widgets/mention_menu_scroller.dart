import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

class MentionMenuScroller extends StatefulWidget {
  const MentionMenuScroller({super.key, required this.builder});

  final MentionMenuScrollerBuilder builder;

  @override
  State<MentionMenuScroller> createState() => _MentionMenuScrollerState();
}

class _MentionMenuScrollerState extends State<MentionMenuScroller> {
  final controller = AutoScrollController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Provider.value(
      value: AutoScrollControllerProvider(controller),
      child: widget.builder.call(context, controller),
    );
  }
}

typedef MentionMenuScrollerBuilder = Widget Function(
  BuildContext context,
  AutoScrollController controller,
);

class AutoScrollControllerProvider {
  AutoScrollControllerProvider(this.controller);

  final AutoScrollController controller;
}
