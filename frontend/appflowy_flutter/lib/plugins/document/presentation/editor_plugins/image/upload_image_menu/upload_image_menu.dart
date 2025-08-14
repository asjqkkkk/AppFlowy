import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:cross_file/cross_file.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'embed_image_url.dart';
import 'preset_colors.dart';
import 'unsplash_image.dart';
import 'upload_image.dart';

enum UploadImageType {
  local,
  url,
  unsplash,
  color;

  String get description => switch (this) {
        UploadImageType.local =>
          LocaleKeys.document_imageBlock_upload_label.tr(),
        UploadImageType.url =>
          LocaleKeys.document_imageBlock_embedLink_label.tr(),
        UploadImageType.unsplash =>
          LocaleKeys.document_imageBlock_unsplash_label.tr(),
        UploadImageType.color => LocaleKeys.document_plugins_cover_colors.tr(),
      };
}

class DesktopImageSelector extends StatefulWidget {
  const DesktopImageSelector({
    super.key,
    required this.supportedTypes,
    this.selectedColor,
    this.onSelectLocalImages,
    this.onSelectNetworkImage,
    this.onSelectAIImage,
    this.onSelectSolidColor,
    this.onSelectGradientColor,
    this.limitMaximumImageSize = false,
    this.allowMultipleImages = false,
  });

  final List<UploadImageType> supportedTypes;
  final String? selectedColor;
  final void Function(List<XFile>)? onSelectLocalImages;
  final void Function(String url)? onSelectAIImage;
  final void Function(String url)? onSelectNetworkImage;
  final void Function(String color)? onSelectSolidColor;
  final void Function(String color)? onSelectGradientColor;
  final bool limitMaximumImageSize;
  final bool allowMultipleImages;

  @override
  State<DesktopImageSelector> createState() => _DesktopImageSelectorState();
}

class _DesktopImageSelectorState extends State<DesktopImageSelector> {
  int currentTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Material(
      color: Colors.transparent,
      child: DefaultTabController(
        length: widget.supportedTypes.length,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildTabBar(theme),
            buildTabContent(),
          ],
        ),
      ),
    );
  }

  Padding buildTabBar(AppFlowyThemeData theme) {
    return Padding(
      padding: EdgeInsets.only(
        left: theme.spacing.xl,
        right: theme.spacing.xl,
        top: theme.spacing.l,
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            top: null,
            child: AFDivider(),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              onTap: (value) => setState(() => currentTabIndex = value),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorAnimation: TabIndicatorAnimation.elastic,
              indicator: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.borderColorScheme.themeThick,
                    width: 2.0,
                  ),
                ),
              ),
              isScrollable: true,
              labelPadding: EdgeInsets.only(
                left: theme.spacing.s,
                right: theme.spacing.s,
                bottom: theme.spacing.s,
              ),
              tabAlignment: TabAlignment.start,
              overlayColor: WidgetStatePropertyAll(Colors.transparent),
              splashFactory: NoSplash.splashFactory,
              padding: EdgeInsets.zero,
              tabs: widget.supportedTypes.map(
                (e) {
                  final index = widget.supportedTypes.indexOf(e);
                  return ImageSelectorTab(
                    type: e,
                    isSelected: currentTabIndex == index,
                    onTap: () {
                      setState(() => currentTabIndex = index);
                    },
                  );
                },
              ).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTabContent() {
    final theme = AppFlowyTheme.of(context);

    final padding = EdgeInsets.symmetric(
      horizontal: theme.spacing.xl,
      vertical: theme.spacing.l,
    );

    return switch (widget.supportedTypes[currentTabIndex]) {
      UploadImageType.local => Expanded(
          child: Container(
            padding: padding,
            width: double.infinity,
            child: FileDropZone(
              allowMultipleImages: widget.allowMultipleImages,
              onPickFiles: widget.onSelectLocalImages!,
            ),
          ),
        ),
      UploadImageType.url => Padding(
          padding: padding,
          child: EmbedImageUrl(
            onSubmit: widget.onSelectNetworkImage!,
          ),
        ),
      UploadImageType.unsplash => Expanded(
          child: UnsplashImageSelector(
            onSelectUnsplashImage: widget.onSelectNetworkImage!,
          ),
        ),
      UploadImageType.color => Padding(
          padding: padding,
          child: PresetColorSelector(
            selectedColor: widget.selectedColor,
            onSelectSolidColor: widget.onSelectSolidColor!,
            onSelectGradientColor: widget.onSelectGradientColor!,
          ),
        )
    };
  }
}

class MobileImageSelector extends StatefulWidget {
  const MobileImageSelector({
    super.key,
    required this.supportedTypes,
    this.onSelectLocalImages,
    this.onSelectNetworkImage,
    this.onSelectAIImage,
    this.onSelectSolidColor,
    this.onSelectGradientColor,
    this.limitMaximumImageSize = false,
    this.allowMultipleImages = false,
  });

  final List<UploadImageType> supportedTypes;
  final void Function(List<XFile>)? onSelectLocalImages;
  final void Function(String url)? onSelectAIImage;
  final void Function(String url)? onSelectNetworkImage;
  final void Function(String color)? onSelectSolidColor;
  final void Function(String color)? onSelectGradientColor;
  final bool limitMaximumImageSize;
  final bool allowMultipleImages;

  @override
  State<MobileImageSelector> createState() => _MobileImageSelectorState();
}

class _MobileImageSelectorState extends State<MobileImageSelector> {
  int currentTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Material(
      color: Colors.transparent,
      child: DefaultTabController(
        length: widget.supportedTypes.length,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildTabBar(theme),
            buildTabContent(),
          ],
        ),
      ),
    );
  }

  Padding buildTabBar(AppFlowyThemeData theme) {
    return Padding(
      padding: EdgeInsets.only(
        left: theme.spacing.xl,
        right: theme.spacing.xl,
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            top: null,
            child: AFDivider(),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              onTap: (value) => setState(() => currentTabIndex = value),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorAnimation: TabIndicatorAnimation.elastic,
              indicator: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.borderColorScheme.themeThick,
                    width: 2.0,
                  ),
                ),
              ),
              isScrollable: true,
              labelPadding: EdgeInsets.only(
                left: theme.spacing.s,
                right: theme.spacing.s,
                bottom: theme.spacing.s,
              ),
              tabAlignment: TabAlignment.start,
              overlayColor: WidgetStatePropertyAll(Colors.transparent),
              splashFactory: NoSplash.splashFactory,
              padding: EdgeInsets.zero,
              tabs: widget.supportedTypes.map(
                (e) {
                  final index = widget.supportedTypes.indexOf(e);
                  return ImageSelectorTab(
                    type: e,
                    isSelected: currentTabIndex == index,
                    onTap: () {
                      setState(() => currentTabIndex = index);
                    },
                  );
                },
              ).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTabContent() {
    final theme = AppFlowyTheme.of(context);

    final padding = EdgeInsets.symmetric(
      horizontal: theme.spacing.xl,
      vertical: theme.spacing.l,
    );

    return switch (widget.supportedTypes[currentTabIndex]) {
      UploadImageType.local => Container(
          padding: padding,
          width: double.infinity,
          child: UploadImageButton(
            allowMultipleImages: widget.allowMultipleImages,
            onPickFiles: widget.onSelectLocalImages!,
          ),
        ),
      UploadImageType.url => Padding(
          padding: padding,
          child: EmbedImageUrl(
            onSubmit: widget.onSelectNetworkImage!,
          ),
        ),
      UploadImageType.unsplash => Expanded(
          child: UnsplashImageSelector(
            textFieldSize: AFTextFieldSize.l,
            onTapOutside: (context, event) => FocusScope.of(context).unfocus(),
            gridViewPadding: EdgeInsets.symmetric(
              horizontal: theme.spacing.xl,
            ),
            onSelectUnsplashImage: widget.onSelectNetworkImage!,
          ),
        ),
      UploadImageType.color => Padding(
          padding: padding,
          child: PresetColorSelector(
            selectedColor: null,
            onSelectSolidColor: widget.onSelectSolidColor!,
            onSelectGradientColor: widget.onSelectGradientColor!,
          ),
        )
    };
  }
}

class ImageSelectorTab extends StatelessWidget {
  const ImageSelectorTab({
    super.key,
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  final UploadImageType type;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Padding(
      padding: EdgeInsets.all(theme.spacing.xs),
      child: Text(
        type.description,
        style: theme.textStyle.body.enhanced(
          color: isSelected
              ? theme.textColorScheme.primary
              : theme.textColorScheme.tertiary,
        ),
      ),
    );
  }
}
