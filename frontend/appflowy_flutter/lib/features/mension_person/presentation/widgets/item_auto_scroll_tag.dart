import 'package:appflowy/features/mension_person/logic/mention_bloc.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import 'mention_menu_scroller.dart';

class MentionMenuItemAutoScrollTag extends StatelessWidget {
  const MentionMenuItemAutoScrollTag({
    super.key,
    required this.id,
    required this.child,
  });

  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<MentionBloc>(),
        theme = AppFlowyTheme.of(context),
        controllerProvider = context.read<AutoScrollControllerProvider>();
    final index = bloc.state.itemMap.items.indexWhere((e) => e.id == id);
    return AutoScrollTag(
      key: ValueKey(index),
      index: index,
      controller: controllerProvider.controller,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.spacing.m),
        child: child,
      ),
    );
  }
}
