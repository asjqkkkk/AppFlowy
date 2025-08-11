import 'dart:math';

import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/application/page_style/document_page_style_bloc.dart';
import 'package:appflowy/plugins/document/application/document_appearance_cubit.dart';
import 'package:appflowy/plugins/document/application/document_bloc.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/cover/document_immersive_cover_bloc.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/image/custom_image_block_component/custom_image_block_component.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/image/image_util.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/migration/editor_migration.dart';
import 'package:appflowy/plugins/document/presentation/editor_style.dart';
import 'package:appflowy/shared/flowy_tint_colors.dart';
import 'package:appflowy/shared/icon_emoji_picker/flowy_icon_emoji_picker.dart';
import 'package:appflowy/shared/icon_emoji_picker/tab.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_editor/appflowy_editor.dart' hide UploadImageMenu;
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:string_validator/string_validator.dart';

import '../cover/cover_content.dart';
import '../cover/cover_controls.dart';
import 'cover_title.dart';
import 'emoji_icon_widget.dart';

const double kCoverHeight = 280.0;
const double kIconHeight = 60.0;
const double kToolbarHeight = 40.0; // with padding to the top

// Remove this widget if the desktop support immersive cover.
class DocumentHeaderBlockKeys {
  const DocumentHeaderBlockKeys._();

  static const String coverType = 'cover_selection_type';
  static const String coverDetails = 'cover_selection';
  static const String icon = 'selected_icon';
}

// for the version under 0.5.5, including 0.5.5
enum CoverType {
  none,
  color,
  file,
  asset,
  gradient;

  static CoverType fromString(String? value) {
    if (value == null) {
      return CoverType.none;
    }
    return CoverType.values.firstWhere(
      (e) => e.toString() == value,
      orElse: () => CoverType.none,
    );
  }
}

// This key is used to intercept the selection event in the document cover widget.
const _interceptorKey = 'document_cover_widget_interceptor';

class DocumentHeader extends StatefulWidget {
  const DocumentHeader({
    super.key,
    required this.node,
    required this.editorState,
    required this.iconTabs,
    required this.onIconChanged,
    required this.view,
  });

  final Node node;
  final EditorState editorState;
  final List<PickerTabType> iconTabs;
  final ValueChanged<EmojiIconData> onIconChanged;
  final ViewPB view;

  @override
  State<DocumentHeader> createState() => _DocumentHeaderState();
}

class _DocumentHeaderState extends State<DocumentHeader> {
  final isHeaderHovered = ValueNotifier<bool>(false);
  late final gestureInterceptor = SelectionGestureInterceptor(
    key: _interceptorKey,
    canTap: (details) => !isPointerEventInBounds(details.globalPosition),
    canPanStart: (details) => !isPointerEventInBounds(details.globalPosition),
  );

  int retryCount = 0;

  RenderBox? get renderBox => context.findRenderObject() as RenderBox?;

  @override
  void initState() {
    super.initState();
    widget.editorState.service.selectionService
        .registerGestureInterceptor(gestureInterceptor);
  }

  @override
  void dispose() {
    isHeaderHovered.dispose();
    widget.editorState.service.selectionService
        .unregisterGestureInterceptor(_interceptorKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editorStyle = widget.editorState.editorStyle;
    final padding =
        editorStyle.padding + const EdgeInsets.symmetric(horizontal: 44);
    final maxWidth = editorStyle.maxWidth ?? double.infinity;

    return IgnorePointer(
      ignoring: !widget.editorState.editable,
      child: BlocProvider(
        create: (context) => DocumentImmersiveCoverBloc(view: widget.view)
          ..add(const DocumentImmersiveCoverEvent.initial()),
        child: BlocBuilder<DocumentImmersiveCoverBloc,
            DocumentImmersiveCoverState>(
          builder: (context, state) {
            final hasIcon = state.icon != null &&
                state.icon != EmojiIconData.none() &&
                state.icon!.emoji.isNotEmpty;
            final hasCover = state.cover.type != PageStyleCoverImageType.none;

            return LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        SizedBox(
                          height: calculateOverallHeight(hasIcon, hasCover),
                          child: DocumentHeaderToolbar(
                            onIconOrCoverChanged: _saveIconOrCover,
                            node: widget.node,
                            editorState: widget.editorState,
                            hasCover: hasCover,
                            hasIcon: hasIcon,
                            iconTabs: widget.iconTabs,
                            offset: _calculateIconLeft(context, constraints),
                            isHeaderHovered: isHeaderHovered,
                            documentId: widget.view.id,
                          ),
                        ),
                        if (hasCover)
                          DocumentCover(
                            view: widget.view,
                            editorState: widget.editorState,
                            node: widget.node,
                            onChangeCover: (type, details) {
                              _saveIconOrCover(cover: (type, details));
                            },
                          ),
                        if (hasIcon)
                          alignedCoverIcon(
                            hasCover,
                            state.icon!,
                            padding,
                            maxWidth,
                          ),
                      ],
                    ),
                    alignedTitle(
                      padding,
                      maxWidth,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget alignedTitle(
    EdgeInsetsGeometry padding,
    double maxWidth,
  ) {
    return Center(
      child: MouseRegion(
        onEnter: (event) => isHeaderHovered.value = true,
        onExit: (event) => isHeaderHovered.value = false,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: padding,
          child: CoverTitle(
            view: widget.view,
          ),
        ),
      ),
    );
  }

  Widget alignedCoverIcon(
    bool hasCover,
    EmojiIconData viewIcon,
    EdgeInsetsGeometry padding,
    double maxWidth,
  ) {
    return Positioned.fill(
      bottom: hasCover ? kToolbarHeight - kIconHeight / 2 : kToolbarHeight,
      top: null,
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: padding,
          child: Row(
            children: [
              DocumentIcon(
                editorState: widget.editorState,
                node: widget.node,
                icon: viewIcon,
                documentId: widget.view.id,
                onChangeIcon: (icon) => _saveIconOrCover(icon: icon),
              ),
              Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateIconLeft(BuildContext context, BoxConstraints constraints) {
    final editorState = context.read<EditorState>();
    final appearanceCubit = context.read<DocumentAppearanceCubit>();

    final renderBox = editorState.renderBox;

    if (renderBox == null || !renderBox.hasSize) {}

    var renderBoxWidth = 0.0;
    if (renderBox != null && renderBox.hasSize) {
      renderBoxWidth = renderBox.size.width;
    } else if (retryCount <= 3) {
      retryCount++;
      // this is a workaround for the issue that the renderBox is not initialized
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        setState(() {});
      });
      return 0;
    }

    // if the renderBox width equals to 0, it means the editor is not initialized
    final editorWidth = renderBoxWidth != 0
        ? min(renderBoxWidth, appearanceCubit.state.width)
        : appearanceCubit.state.width;

    // left padding + editor width + right padding = the width of the editor
    final leftOffset = (constraints.maxWidth - editorWidth) / 2.0 +
        EditorStyleCustomizer.documentPadding.right;

    // ensure the offset is not negative
    return max(0, leftOffset);
  }

  double calculateOverallHeight(bool hasIcon, bool hasCover) {
    return switch ((hasIcon, hasCover)) {
      (true, true) => kCoverHeight + kToolbarHeight,
      (true, false) => 50 + kIconHeight + kToolbarHeight,
      (false, true) => kCoverHeight + kToolbarHeight,
      (false, false) => kToolbarHeight,
    };
  }

  void _saveIconOrCover({
    (CoverType, String?)? cover,
    EmojiIconData? icon,
  }) async {
    if (!widget.editorState.editable) {
      return;
    }

    final transaction = widget.editorState.transaction;
    final Map<String, dynamic> attributes = {
      CustomImageBlockKeys.imageType: '1',
    };

    if (cover != null) {
      attributes[DocumentHeaderBlockKeys.coverType] = cover.$1.toString();
      attributes[DocumentHeaderBlockKeys.coverDetails] = cover.$2;
    }
    if (icon != null) {
      attributes[DocumentHeaderBlockKeys.icon] = icon.emoji;
      widget.onIconChanged(icon);
    }

    // only keep existing cover attributes when we're only changing the icon
    if (cover == null && icon != null) {
      final existingCoverType =
          widget.node.attributes[DocumentHeaderBlockKeys.coverType];
      final existingCoverDetails =
          widget.node.attributes[DocumentHeaderBlockKeys.coverDetails];
      if (existingCoverType != null) {
        attributes[DocumentHeaderBlockKeys.coverType] = existingCoverType;
      }
      if (existingCoverDetails != null) {
        attributes[DocumentHeaderBlockKeys.coverDetails] = existingCoverDetails;
      }
    }

    // compatible with version <= 0.5.5.
    transaction.updateNode(widget.node, attributes);
    await widget.editorState.apply(transaction);

    // compatible with version > 0.5.5.
    // only migrate cover data when we're actually changing the cover
    if (cover != null) {
      EditorMigration.migrateCoverIfNeeded(
        widget.view,
        attributes,
        overwrite: true,
      );
    }
  }

  bool isPointerEventInBounds(Offset offset) {
    if (renderBox == null) {
      return false;
    }

    final localPosition = renderBox!.globalToLocal(offset);
    return renderBox!.paintBounds.contains(localPosition);
  }
}

@visibleForTesting
class DocumentHeaderToolbar extends StatefulWidget {
  const DocumentHeaderToolbar({
    super.key,
    required this.node,
    required this.editorState,
    required this.hasCover,
    required this.hasIcon,
    required this.onIconOrCoverChanged,
    required this.offset,
    this.documentId,
    required this.isHeaderHovered,
    required this.iconTabs,
  });

  final Node node;
  final EditorState editorState;
  final bool hasCover;
  final bool hasIcon;
  final void Function({(CoverType, String?)? cover, EmojiIconData? icon})
      onIconOrCoverChanged;
  final double offset;
  final String? documentId;
  final ValueNotifier<bool> isHeaderHovered;
  final List<PickerTabType> iconTabs;

  @override
  State<DocumentHeaderToolbar> createState() => _DocumentHeaderToolbarState();
}

class _DocumentHeaderToolbarState extends State<DocumentHeaderToolbar> {
  final popoverController = PopoverController();

  bool isPopoverOpen = false;
  bool isToolbarHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return MouseRegion(
      onEnter: (_) => setIsToolbarHovered(true),
      onExit: (_) {
        if (!isPopoverOpen) {
          setIsToolbarHovered(false);
        }
      },
      child: Container(
        alignment: Alignment.bottomLeft,
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: widget.offset),
        child: ValueListenableBuilder<bool>(
          valueListenable: widget.isHeaderHovered,
          builder: (context, isHeaderHovered, child) {
            if (!isToolbarHovered && !isPopoverOpen && !isHeaderHovered) {
              return const SizedBox.shrink();
            }
            if (widget.hasCover && widget.hasIcon) {
              return const SizedBox.shrink();
            }

            return Row(
              spacing: theme.spacing.m,
              children: [
                if (!widget.hasCover) addCoverButton(theme),
                if (widget.hasIcon)
                  removeIconButton(theme)
                else
                  addIconButton(theme),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget addCoverButton(AppFlowyThemeData theme) {
    return AFGhostButton.normal(
      onTap: () => widget.onIconOrCoverChanged(
        cover: (CoverType.color, FlowyTint.tint1.id),
      ),
      padding: EdgeInsets.all(theme.spacing.xs),
      builder: (context, isHovering, disabled) {
        return Row(
          spacing: theme.spacing.m,
          children: [
            FlowySvg(
              FlowySvgs.add_cover_s,
              color: theme.iconColorScheme.primary,
            ),
            Text(
              LocaleKeys.document_plugins_cover_addCover.tr(),
              style: theme.textStyle.body.standard(
                color: theme.textColorScheme.primary,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget removeIconButton(AppFlowyThemeData theme) {
    return AFGhostButton.normal(
      onTap: () => widget.onIconOrCoverChanged(icon: EmojiIconData.none()),
      padding: EdgeInsets.all(theme.spacing.xs),
      builder: (context, isHovering, disabled) {
        return Row(
          spacing: theme.spacing.m,
          children: [
            FlowySvg(
              FlowySvgs.add_icon_s,
              color: theme.iconColorScheme.primary,
            ),
            Text(
              LocaleKeys.document_plugins_cover_removeIcon.tr(),
              style: theme.textStyle.body.standard(
                color: theme.textColorScheme.primary,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget addIconButton(AppFlowyThemeData theme) {
    return AppFlowyPopover(
      onClose: () => setState(() => isPopoverOpen = false),
      controller: popoverController,
      offset: const Offset(0, 8),
      direction: PopoverDirection.bottomWithCenterAligned,
      constraints: BoxConstraints.loose(const Size(360, 380)),
      margin: EdgeInsets.zero,
      child: AFGhostButton.normal(
        onTap: () {
          if (!isPopoverOpen) {
            isPopoverOpen = true;
            popoverController.show();
          }
        },
        padding: EdgeInsets.all(theme.spacing.xs),
        builder: (context, isHovering, disabled) {
          return Row(
            spacing: theme.spacing.m,
            children: [
              FlowySvg(
                FlowySvgs.add_icon_s,
                color: theme.iconColorScheme.primary,
              ),
              Text(
                LocaleKeys.document_plugins_cover_addIcon.tr(),
                style: theme.textStyle.body.standard(
                  color: theme.textColorScheme.primary,
                ),
              ),
            ],
          );
        },
      ),
      popupBuilder: (popoverContext) {
        isPopoverOpen = true;
        return FlowyIconEmojiPicker(
          tabs: widget.iconTabs,
          documentId: widget.documentId,
          onSelectedEmoji: (r) {
            widget.onIconOrCoverChanged(icon: r.data);
            if (!r.keepOpen) popoverController.close();
          },
        );
      },
    );
  }

  void setIsToolbarHovered(bool value) {
    if (isToolbarHovered != value) {
      setState(() => isToolbarHovered = value);
    }
  }
}

@visibleForTesting
class DocumentCover extends StatefulWidget {
  const DocumentCover({
    super.key,
    required this.view,
    required this.node,
    required this.editorState,
    required this.onChangeCover,
  });

  final ViewPB view;
  final Node node;
  final EditorState editorState;
  final void Function(CoverType type, String? details) onChangeCover;

  @override
  State<DocumentCover> createState() => DocumentCoverState();
}

class DocumentCoverState extends State<DocumentCover> {
  bool isHovered = false;
  bool isOpen = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kCoverHeight,
      child: MouseRegion(
        onEnter: (_) => setState(() => isHovered = true),
        onExit: (_) => setState(() => isHovered = false),
        child: BlocBuilder<DocumentImmersiveCoverBloc,
            DocumentImmersiveCoverState>(
          builder: (context, state) {
            return Stack(
              children: [
                SizedBox.expand(
                  child: CoverContent(
                    type: state.cover.type,
                    value: state.cover.value,
                    userProfile:
                        context.read<DocumentBloc>().state.userProfilePB,
                    height: kCoverHeight,
                    width: double.infinity,
                  ),
                ),
                if (isHovered || isOpen)
                  CoverControls(
                    cover: (
                      coverTypeFromPageStyleCoverImageType(state.cover.type),
                      state.cover.value
                    ),
                    isLocalMode: context.read<DocumentBloc>().isLocalMode,
                    onCoverChanged: onCoverChanged,
                    onOpen: () => isOpen = true,
                    onClose: () => isOpen = false,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  CoverType coverTypeFromPageStyleCoverImageType(PageStyleCoverImageType type) {
    return switch (type) {
      PageStyleCoverImageType.none => CoverType.none,
      PageStyleCoverImageType.localImage => CoverType.file,
      PageStyleCoverImageType.builtInImage => CoverType.asset,
      PageStyleCoverImageType.pureColor => CoverType.color,
      PageStyleCoverImageType.gradientColor => CoverType.gradient,
      _ => CoverType.none,
    };
  }

  Future<void> onCoverChanged(CoverType type, String? details) async {
    final previousType = CoverType.fromString(
      widget.node.attributes[DocumentHeaderBlockKeys.coverType],
    );
    final previousDetails =
        widget.node.attributes[DocumentHeaderBlockKeys.coverDetails];

    final isLocalMode = context.read<DocumentBloc>().isLocalMode;

    bool isFileType(CoverType type, String? details) =>
        type == CoverType.file && details != null && !isURL(details);

    if (isFileType(type, details)) {
      if (isLocalMode) {
        details = await saveImageToLocalStorage(details!);
      } else {
        (details, _) = await saveImageToCloudStorage(details!, widget.view.id);
      }
    }
    widget.onChangeCover(type, details);

    // After cover change, delete from localstorage if previous cover was image type
    if (isFileType(previousType, previousDetails) && isLocalMode) {
      await deleteImageFromLocalStorage(previousDetails);
    }
  }
}

@visibleForTesting
class DocumentIcon extends StatefulWidget {
  const DocumentIcon({
    super.key,
    required this.node,
    required this.editorState,
    required this.icon,
    required this.onChangeIcon,
    this.documentId,
  });

  final Node node;
  final EditorState editorState;
  final EmojiIconData icon;
  final String? documentId;
  final ValueChanged<EmojiIconData> onChangeIcon;

  @override
  State<DocumentIcon> createState() => _DocumentIconState();
}

class _DocumentIconState extends State<DocumentIcon> {
  final popoverController = PopoverController();

  @override
  Widget build(BuildContext context) {
    return AppFlowyPopover(
      direction: PopoverDirection.bottomWithCenterAligned,
      controller: popoverController,
      offset: const Offset(0, 8),
      constraints: BoxConstraints.loose(const Size(360, 380)),
      margin: EdgeInsets.zero,
      child: EmojiIconWidget(emoji: widget.icon),
      popupBuilder: (BuildContext popoverContext) {
        return FlowyIconEmojiPicker(
          initialType: widget.icon.type.toPickerTabType(),
          tabs: const [
            PickerTabType.emoji,
            PickerTabType.icon,
            PickerTabType.custom,
          ],
          documentId: widget.documentId,
          onSelectedEmoji: (r) {
            widget.onChangeIcon(r.data);
            if (!r.keepOpen) {
              popoverController.close();
            }
          },
        );
      },
    );
  }
}
