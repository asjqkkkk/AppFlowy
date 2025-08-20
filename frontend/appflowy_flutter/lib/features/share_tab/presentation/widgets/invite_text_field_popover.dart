import 'package:appflowy/features/mension_person/presentation/mention_menu.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import 'guest_tag.dart';

class InviteTextFieldPopover extends StatelessWidget {
  const InviteTextFieldPopover({
    super.key,
    required this.maxWidth,
    required this.items,
    required this.title,
    required this.selectedId,
    required this.controller,
    required this.onItemSelected,
  });

  final double maxWidth;
  final String selectedId;
  final List<OptionItem> items;
  final String title;
  final AutoScrollController controller;
  final ValueChanged<OptionItem> onItemSelected;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context), spacing = theme.spacing;
    if (items.isEmpty) return SizedBox.shrink();
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: 420,
        maxWidth: maxWidth,
      ),
      child: ListView(
        shrinkWrap: true,
        controller: controller,
        padding: EdgeInsets.all(spacing.m),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.m,
              vertical: spacing.xs,
            ),
            child: Text(
              title,
              style: theme.textStyle.caption.enhanced(
                color: theme.textColorScheme.tertiary,
              ),
            ),
          ),
          ...List.generate(
            items.length,
            (index) {
              final item = items[index];
              return AutoScrollTag(
                key: ValueKey(item.id),
                index: index,
                controller: controller,
                child: buildItem(item, context, selectedId == item.id),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget buildItem(OptionItem item, BuildContext context, bool isSelected) {
    final theme = AppFlowyTheme.of(context);

    if (item is PersonOptionItem) {
      return InviteDropDownMenuItem(
        person: item.value,
        selected: isSelected,
        onTap: () => onItemSelected.call(item),
      );
    } else if (item is EmailSuggestionItem) {
      return AFMenuItem(
        selected: isSelected,
        cursor: SystemMouseCursors.click,
        backgroundColor: context.mentionItemBGColor,
        padding: EdgeInsets.symmetric(
          vertical: theme.spacing.s,
          horizontal: theme.spacing.m,
        ),
        leading: FlowySvg(
          FlowySvgs.mention_menu_invite_icon_m,
          size: Size.square(20),
          color: theme.iconColorScheme.primary,
        ),
        title: Text(
          item.value,
          style: theme.textStyle.body
              .standard(color: theme.textColorScheme.primary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => onItemSelected.call(item),
      );
    } else {
      return SizedBox.shrink();
    }
  }
}

class InviteDropDownMenuItem extends StatelessWidget {
  const InviteDropDownMenuItem({
    super.key,
    required this.person,
    required this.onTap,
    this.selected = false,
  });

  final MentionablePersonPB person;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return AFMenuItem(
      selected: selected,
      cursor: SystemMouseCursors.click,
      backgroundColor: context.mentionItemBGColor,
      padding: EdgeInsets.symmetric(
        vertical: theme.spacing.s,
        horizontal: theme.spacing.m,
      ),
      leading: AFAvatar(name: person.name, url: person.avatarUrl),
      title: _buildTitle(context),
      subtitle: Text(
        person.email,
        style: theme.textStyle.caption.standard(
          color: theme.textColorScheme.secondary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }

  Widget _buildTitle(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            person.name,
            style: theme.textStyle.body.standard(
              color: theme.textColorScheme.primary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (person.role == MentionablePersonTypePB.WorkspaceGuest) ...[
          HSpace(theme.spacing.m),
          const GuestTag(),
        ],
      ],
    );
  }
}

abstract class OptionItem<T> {
  OptionItem({required this.value});

  final T value;

  String get id;
}

class PersonOptionItem extends OptionItem<MentionablePersonPB> {
  PersonOptionItem({
    required super.value,
  });

  @override
  String get id => value.uuid;
}

class EmailSuggestionItem extends OptionItem<String> {
  EmailSuggestionItem({
    required super.value,
  });

  @override
  String get id => value;
}
