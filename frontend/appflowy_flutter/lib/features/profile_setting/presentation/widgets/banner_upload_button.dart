import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flutter/material.dart';

class BannerUploadButton extends StatefulWidget {
  const BannerUploadButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<BannerUploadButton> createState() => _BannerUploadButtonState();
}

class _BannerUploadButtonState extends State<BannerUploadButton> {
  final ValueNotifier<bool> hoveringNotifier = ValueNotifier(false);

  @override
  void dispose() {
    hoveringNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (event) => hoveringNotifier.value = true,
      onExit: (event) => hoveringNotifier.value = false,
      child: GestureDetector(
        onTap: widget.onTap,
        child: ValueListenableBuilder<bool>(
          valueListenable: hoveringNotifier,
          builder: (context, hovering, child) {
            return Container(
              height: 52,
              decoration: BoxDecoration(
                border: Border.all(color: theme.borderColorScheme.primary),
                borderRadius: BorderRadius.circular(theme.spacing.m),
                color: hovering ? theme.fillColorScheme.contentHover : null,
              ),
              child: Center(
                child: FlowySvg(
                  FlowySvgs.profile_add_icon_m,
                  size: Size.square(20),
                  color: theme.iconColorScheme.primary,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
