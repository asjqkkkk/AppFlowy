import 'package:appflowy/features/mension_person/presentation/mention_menu.dart';
import 'package:appflowy/features/share_tab/data/models/share_role.dart';
import 'package:appflowy/features/share_tab/data/models/shared_user.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/shared/custom_image_cache_manager.dart';
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

    if (item is UserOptionItem) {
      return InviteDropDownMenuItem(
        user: item.value,
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
    required this.user,
    required this.onTap,
    this.selected = false,
  });

  final SharedUser user;
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
      leading: AFAvatar(
        name: user.name,
        url: user.avatarUrl,
        email: user.email,
        cacheManager: CustomAvatarCacheManager(),
      ),
      title: _buildTitle(context),
      subtitle: Text(
        user.email,
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
            user.name,
            style: theme.textStyle.body.standard(
              color: theme.textColorScheme.primary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (user.role == ShareRole.guest) ...[
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

class UserOptionItem extends OptionItem<SharedUser> {
  UserOptionItem({
    required super.value,
  });

  @override
  String get id => value.email;
}

class EmailSuggestionItem extends OptionItem<String> {
  EmailSuggestionItem({
    required super.value,
  });

  @override
  String get id => value;
}
