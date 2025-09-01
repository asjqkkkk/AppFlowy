import 'package:appflowy/shared/custom_image_cache_manager.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.iconUrl,
    required this.name,
    required this.email,
    required this.size,
    this.isHovering = false,
    this.header,
    this.decoration,
  });

  final String iconUrl;
  final String name;
  final String email;

  final AFAvatarSize size;
  final Decoration? decoration;
  final Map<String, String>? header;

  // If true, a border will be applied on top of the avatar
  final bool isHovering;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return SizedBox.square(
      dimension: size.size,
      child: DecoratedBox(
        decoration: decoration ??
            BoxDecoration(
              shape: BoxShape.circle,
              border: isHovering
                  ? Border.all(
                      color: theme.iconColorScheme.primary,
                      width: 4,
                    )
                  : null,
            ),
        child: AFAvatar(
          url: iconUrl,
          name: name,
          email: email,
          size: size,
          cacheManager: CustomAvatarCacheManager(),
          httpHeaders: header,
        ),
      ),
    );
  }
}
