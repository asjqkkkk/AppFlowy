import 'dart:ui';

import 'package:appflowy/features/share_tab/data/models/share_access_level.dart';
import 'package:appflowy/features/share_tab/data/models/share_role.dart';
import 'package:appflowy/features/share_tab/data/models/shared_user.dart';
import 'package:appflowy/features/share_tab/presentation/widgets/invite_text_field_popover.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/shared/custom_image_cache_manager.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/widget/flowy_tooltip.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';

class InvitingItem extends StatelessWidget {
  const InvitingItem({
    super.key,
    required this.item,
    required this.onRemove,
  });

  final OptionItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return buildItem(context);
  }

  Widget buildItem(BuildContext context) {
    if (item is UserOptionItem) {
      return buildPersonItem(context, item.value);
    } else if (item is EmailSuggestionItem) {
      return buildGuestItem(
        context,
        SharedUser(
          email: item.value,
          name: item.value,
          role: ShareRole.guest,
          accessLevel: ShareAccessLevel.readOnly,
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget buildPersonItem(BuildContext context, SharedUser user) {
    if (user.role == ShareRole.guest) {
      return buildGuestItem(context, user);
    }
    final theme = AppFlowyTheme.of(context), spacing = theme.spacing;
    return FlowyTooltip(
      message: user.email,
      preferBelow: false,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(spacing.s),
          color: theme.surfaceContainerColorScheme.layer02,
        ),
        padding: EdgeInsets.fromLTRB(spacing.xs, 1, 0, 1),
        child: Row(
          children: [
            AFAvatar(
              url: user.avatarUrl,
              name: user.name,
              email: user.email,
              size: AFAvatarSize.xs,
              cacheManager: CustomAvatarCacheManager(),
            ),
            HSpace(spacing.xs),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 100),
              child: Text(
                user.name,
                style: theme.textStyle.body
                    .standard(color: theme.textColorScheme.primary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            buildRemoveButton(context),
          ],
        ),
      ),
    );
  }

  Widget buildGuestItem(BuildContext context, SharedUser user) {
    final theme = AppFlowyTheme.of(context), spacing = theme.spacing;
    final hasAvatar = user.avatarUrl?.isNotEmpty ?? false;
    String displayText = user.email;
    if (user.name.isNotEmpty) {
      displayText = user.name;
    }
    return FlowyTooltip(
      message:
          LocaleKeys.shareTab_dropdownMenu_inviteAsGuest.tr(args: [user.email]),
      preferBelow: false,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(spacing.s),
          color: theme.fillColorScheme.warningLight,
        ),
        padding: EdgeInsets.fromLTRB(spacing.xs, 2, 0, 2),
        child: Row(
          children: [
            hasAvatar
                ? AFAvatar(
                    url: user.avatarUrl,
                    name: user.name,
                    email: user.email,
                    size: AFAvatarSize.xs,
                    cacheManager: CustomAvatarCacheManager(),
                  )
                : FlowySvg(
                    FlowySvgs.guest_inviting_item_m,
                    size: Size.square(20),
                    color: theme.borderColorScheme.warningThick,
                  ),
            HSpace(spacing.xs),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 100),
              child: Text(
                displayText,
                style: theme.textStyle.body
                    .standard(color: theme.textColorScheme.primary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            buildRemoveButton(context),
          ],
        ),
      ),
    );
  }

  Widget buildRemoveButton(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onRemove,
        behavior: HitTestBehavior.opaque,
        child: FlowySvg(
          FlowySvgs.remove_inviting_item_m,
          size: Size.square(20),
          color: theme.iconColorScheme.secondary,
        ),
      ),
    );
  }
}

class HorizontalInvitingItems extends StatelessWidget {
  const HorizontalInvitingItems({
    super.key,
    required this.items,
    required this.controller,
    required this.onItemRemoved,
  });

  final List<OptionItem> items;
  final ScrollController controller;
  final ValueChanged<OptionItem> onItemRemoved;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final spacing = AppFlowyTheme.of(context).spacing;
    return Focus(
      descendantsAreFocusable: false,
      child: MouseRegion(
        cursor: SystemMouseCursors.basic,
        child: Padding(
          padding: EdgeInsets.fromLTRB(spacing.m, 0, spacing.xs, 0),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.mouse,
                PointerDeviceKind.touch,
                PointerDeviceKind.trackpad,
                PointerDeviceKind.stylus,
                PointerDeviceKind.invertedStylus,
              },
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: controller,
              child: Wrap(
                spacing: 4,
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  return InvitingItem(
                    item: item,
                    onRemove: () => onItemRemoved(item),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
