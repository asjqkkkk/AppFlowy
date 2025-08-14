import 'package:appflowy/features/workspace/logic/workspace_bloc.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/image/upload_image_menu/upload_image_menu.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/plugins.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../editor_drop_manager.dart';

class CoverControls extends StatefulWidget {
  const CoverControls({
    super.key,
    this.cover,
    required this.isLocalMode,
    required this.onCoverChanged,
    required this.onOpen,
    required this.onClose,
  });

  final bool isLocalMode;
  final (CoverType type, String? details)? cover;
  final void Function(CoverType type, String? details) onCoverChanged;
  final void Function() onOpen;
  final void Function() onClose;

  @override
  State<CoverControls> createState() => _CoverControlsState();
}

class _CoverControlsState extends State<CoverControls> {
  final popoverController = PopoverController();

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Positioned(
      bottom: 20,
      right: 50,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: theme.spacing.m,
        children: [
          AppFlowyPopover(
            margin: EdgeInsets.zero,
            constraints: BoxConstraints(
              maxWidth: 400,
              maxHeight: 366,
            ),
            direction: PopoverDirection.bottomWithCenterAligned,
            offset: const Offset(0, 2),
            borderRadius: BorderRadius.circular(theme.spacing.l),
            triggerActions: PopoverTriggerFlags.none,
            controller: popoverController,
            onOpen: () {
              widget.onOpen();
              enableDocumentDragNotifier.value = false;
            },
            onClose: () {
              widget.onClose();
              enableDocumentDragNotifier.value = true;
            },
            popupBuilder: (popoverContext) {
              final selectedColor = switch (widget.cover?.$1) {
                CoverType.color || CoverType.gradient => widget.cover?.$2,
                _ => null,
              };

              return BlocProvider.value(
                value: context.read<UserWorkspaceBloc>(),
                child: DesktopImageSelector(
                  limitMaximumImageSize: !widget.isLocalMode,
                  supportedTypes: const [
                    UploadImageType.color,
                    UploadImageType.local,
                    UploadImageType.url,
                    UploadImageType.unsplash,
                  ],
                  selectedColor: selectedColor,
                  onSelectLocalImages: (files) {
                    if (files.isNotEmpty) {
                      final item = files.first.path;
                      widget.onCoverChanged(CoverType.file, item);
                    }
                  },
                  onSelectNetworkImage: (url) {
                    widget.onCoverChanged(CoverType.file, url);
                    popoverController.close();
                  },
                  onSelectSolidColor: (color) {
                    widget.onCoverChanged(CoverType.color, color);
                  },
                  onSelectGradientColor: (color) {
                    widget.onCoverChanged(CoverType.gradient, color);
                  },
                ),
              );
            },
            child: AFBaseButton(
              backgroundColor: (context, isHovering, disabled, isFocused) {
                if (isHovering) {
                  return theme.surfaceColorScheme.primaryHover;
                }
                return theme.surfaceColorScheme.primary;
              },
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.m,
                vertical: theme.spacing.xs,
              ),
              borderColor: (context, isHovering, disabled, isFocused) =>
                  Colors.transparent,
              borderRadius: theme.spacing.m,
              builder: (context, isHovering, disabled) {
                return Text(
                  LocaleKeys.document_plugins_cover_changeCover.tr(),
                  style: theme.textStyle.body.enhanced(
                    color: theme.textColorScheme.primary,
                  ),
                );
              },
              onTap: () {
                popoverController.show();
                widget.onOpen();
                enableDocumentDragNotifier.value = false;
              },
            ),
          ),
          DeleteCoverButton(
            onTap: () => widget.onCoverChanged(CoverType.none, null),
          ),
        ],
      ),
    );
  }
}

@visibleForTesting
class DeleteCoverButton extends StatelessWidget {
  const DeleteCoverButton({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return FlowyTooltip(
      message: LocaleKeys.document_plugins_cover_removeCover.tr(),
      preferBelow: false,
      child: AFBaseButton(
        backgroundColor: (context, isHovering, disabled, isFocused) {
          if (isHovering) {
            return theme.surfaceColorScheme.primaryHover;
          }
          return theme.surfaceColorScheme.primary;
        },
        padding: EdgeInsets.all(
          theme.spacing.xs,
        ),
        borderColor: (context, isHovering, disabled, isFocused) =>
            Colors.transparent,
        borderRadius: theme.spacing.m,
        builder: (context, isHovering, disabled) {
          return Padding(
            padding: const EdgeInsets.all(2.0),
            child: FlowySvg(
              FlowySvgs.trash_s,
              color: isHovering
                  ? theme.iconColorScheme.errorThick
                  : theme.iconColorScheme.primary,
              size: const Size.square(16),
            ),
          );
        },
        onTap: onTap,
      ),
    );
  }
}
