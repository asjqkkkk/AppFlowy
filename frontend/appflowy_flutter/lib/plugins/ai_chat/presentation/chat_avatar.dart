import 'package:appflowy/workspace/presentation/widgets/user_avatar.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flutter/material.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';

import 'layout_define.dart';

class ChatAIAvatar extends StatelessWidget {
  const ChatAIAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: DesktopAIChatSizes.avatarSize,
      height: DesktopAIChatSizes.avatarSize,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      foregroundDecoration: ShapeDecoration(
        shape: CircleBorder(
          side: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      child: const CircleAvatar(
        backgroundColor: Colors.transparent,
        child: FlowySvg(
          FlowySvgs.app_logo_s,
          size: Size.square(16),
          blendMode: null,
        ),
      ),
    );
  }
}

class ChatUserAvatar extends StatelessWidget {
  const ChatUserAvatar({
    super.key,
    required this.iconUrl,
    required this.name,
    this.defaultName,
  });

  final String iconUrl;
  final String name;
  final String? defaultName;

  @override
  Widget build(BuildContext context) {
    late final Widget child = UserAvatar(
          iconUrl: iconUrl,
          name: _userName(name, defaultName),
          size: AFAvatarSize.m,
        );
    return Container(
      width: DesktopAIChatSizes.avatarSize,
      height: DesktopAIChatSizes.avatarSize,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      foregroundDecoration: ShapeDecoration(
        shape: CircleBorder(
          side: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      child: child,
    );
  }

  /// Return the user name.
  ///
  /// If the user name is empty, return the default user name.
  String _userName(String name, String? defaultName) =>
      name.isEmpty ? (defaultName ?? LocaleKeys.defaultUsername.tr()) : name;
}
