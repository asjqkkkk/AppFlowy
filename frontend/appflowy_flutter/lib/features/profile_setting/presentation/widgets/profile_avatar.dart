import 'package:appflowy/features/profile_setting/logic/profile_setting_bloc.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({super.key});

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context),
        spacing = theme.spacing,
        bloc = context.read<ProfileSettingBloc>(),
        state = bloc.state,
        profile = state.profile;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (event) => setState(() => hovering = true),
      onExit: (event) => setState(() => hovering = false),
      child: GestureDetector(
        onTap: () {},
        child: SizedBox.square(
          dimension: 80,
          child: Stack(
            children: [
              AFAvatar(
                radius: spacing.m,
                size: AFAvatarSize.xxl,
                name: profile.name,
                url: profile.avatarUrl,
              ),
              if (hovering)
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: theme.surfaceColorScheme.overlay,
                    borderRadius: BorderRadius.circular(spacing.m),
                  ),
                  child: Center(
                    child: FlowySvg(
                      FlowySvgs.profile_upload_icon_m,
                      size: Size.square(20),
                      color: theme.iconColorScheme.onFill,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
