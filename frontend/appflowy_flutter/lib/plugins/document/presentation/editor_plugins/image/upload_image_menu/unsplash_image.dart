import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/widgets/flowy_mobile_search_text_field.dart';
import 'package:appflowy/util/debounce.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:unsplash_client/unsplash_client.dart';

const _accessKeyA = 'YyD-LbW5bVolHWZBq5fWRM_';
const _accessKeyB = '3ezkG2XchRFjhNTnK9TE';
const _secretKeyA = '5z4EnxaXjWjWMnuBhc0Ku0u';
const _secretKeyB = 'YW2bsYCZlO-REZaqmV6A';

enum UnsplashImageType {
  // the creator name is under the image
  halfScreen,
  // the creator name is on the image
  fullScreen,
}

typedef OnSelectUnsplashImage = void Function(String url);

class UnsplashImageWidget extends StatefulWidget {
  const UnsplashImageWidget({
    super.key,
    this.type = UnsplashImageType.halfScreen,
    required this.onSelectUnsplashImage,
  });

  final UnsplashImageType type;
  final OnSelectUnsplashImage onSelectUnsplashImage;

  @override
  State<UnsplashImageWidget> createState() => _UnsplashImageWidgetState();
}

class _UnsplashImageWidgetState extends State<UnsplashImageWidget> {
  final unsplash = UnsplashClient(
    settings: const ClientSettings(
      credentials: AppCredentials(
        accessKey: _accessKeyA + _accessKeyB,
        secretKey: _secretKeyA + _secretKeyB,
      ),
    ),
  );

  late Future<List<Photo>> randomPhotos;

  String query = '';

  @override
  void initState() {
    super.initState();
    randomPhotos = unsplash.photos
        .random(count: 18, orientation: PhotoOrientation.landscape)
        .goAndGet();
  }

  @override
  void dispose() {
    unsplash.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 44,
          child: FlowyMobileSearchTextField(
            onChanged: (keyword) => query = keyword,
            onSubmitted: (_) => _search(),
          ),
        ),
        const VSpace(12.0),
        Expanded(
          child: FutureBuilder(
            future: randomPhotos,
            builder: (context, value) {
              final data = value.data;
              if (!value.hasData ||
                  value.connectionState != ConnectionState.done ||
                  data == null ||
                  data.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator.adaptive(),
                );
              }
              return _UnsplashImages(
                type: widget.type,
                photos: data,
                onSelectUnsplashImage: widget.onSelectUnsplashImage,
              );
            },
          ),
        ),
      ],
    );
  }

  void _search() {
    setState(() {
      randomPhotos = unsplash.photos
          .random(
            count: 18,
            orientation: PhotoOrientation.landscape,
            query: query,
          )
          .goAndGet();
    });
  }
}

class UnsplashImageSelector extends StatefulWidget {
  const UnsplashImageSelector({
    super.key,
    this.textFieldSize = AFTextFieldSize.m,
    this.onTapOutside,
    this.gridViewPadding,
    required this.onSelectUnsplashImage,
  });

  final OnSelectUnsplashImage onSelectUnsplashImage;
  final AFTextFieldSize textFieldSize;
  final void Function(BuildContext context, PointerDownEvent event)?
      onTapOutside;
  final EdgeInsetsGeometry? gridViewPadding;

  @override
  State<UnsplashImageSelector> createState() => _UnsplashImageSelectorState();
}

class _UnsplashImageSelectorState extends State<UnsplashImageSelector> {
  final focusNode = FocusNode();
  final unsplash = UnsplashClient(
    settings: const ClientSettings(
      credentials: AppCredentials(
        accessKey: _accessKeyA + _accessKeyB,
        secretKey: _secretKeyA + _secretKeyB,
      ),
    ),
  );
  final debounce = Debounce();
  final List<Photo> photos = [];

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchUnsplashImages(null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (UniversalPlatform.isDesktop) {
        focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    focusNode.dispose();
    unsplash.close();
    debounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Column(
      spacing: theme.spacing.m,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: theme.spacing.xl,
            right: theme.spacing.xl,
            top: theme.spacing.l,
          ),
          child: AFTextField(
            size: widget.textFieldSize,
            hintText: LocaleKeys.document_imageBlock_searchForAnImage.tr(),
            onChanged: debounceSearch,
            focusNode: focusNode,
            onTapOutside: widget.onTapOutside == null
                ? null
                : (event) {
                    widget.onTapOutside!(context, event);
                  },
          ),
        ),
        Expanded(
          child: isLoading
              ? Center(
                  child: SizedBox.square(
                    dimension: 20.0,
                    child: CircularProgressIndicator(
                      color: theme.fillColorScheme.themeThick,
                      strokeWidth: 2.0,
                    ),
                  ),
                )
              : _UnsplashImages(
                  type: UnsplashImageType.fullScreen,
                  padding: widget.gridViewPadding,
                  photos: photos,
                  onSelectUnsplashImage: widget.onSelectUnsplashImage,
                ),
        ),
      ],
    );
  }

  void debounceSearch(String keyword) {
    debounce.call(() => fetchUnsplashImages(keyword));
  }

  void fetchUnsplashImages(String? query) async {
    setState(() {
      isLoading = true;
    });

    List<Photo> newPhotos;
    try {
      newPhotos = await unsplash.photos
          .random(
            count: 18,
            orientation: PhotoOrientation.landscape,
            query: query,
          )
          .goAndGet();
    } catch (e) {
      Log.error(e, 'Failed to fetch Unsplash images');
      newPhotos = [];
    }

    if (!mounted) return;

    setState(() {
      photos
        ..clear()
        ..addAll(newPhotos);
      isLoading = false;
    });
  }
}

class _UnsplashImages extends StatefulWidget {
  const _UnsplashImages({
    required this.type,
    required this.photos,
    required this.onSelectUnsplashImage,
    this.padding,
  });

  final UnsplashImageType type;
  final List<Photo> photos;
  final EdgeInsetsGeometry? padding;
  final OnSelectUnsplashImage onSelectUnsplashImage;

  @override
  State<_UnsplashImages> createState() => _UnsplashImagesState();
}

class _UnsplashImagesState extends State<_UnsplashImages> {
  int _selectedPhotoIndex = -1;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: theme.spacing.m,
      crossAxisSpacing: theme.spacing.m,
      childAspectRatio: 3 / 2,
      padding: widget.padding ??
          EdgeInsets.only(
            left: theme.spacing.xl,
            right: theme.spacing.xl,
            bottom: theme.spacing.l,
          ),
      children: widget.photos.asMap().entries.map((entry) {
        final index = entry.key;
        final photo = entry.value;
        return _UnsplashImage(
          type: widget.type,
          photo: photo,
          isSelected: index == _selectedPhotoIndex,
          onTap: () {
            widget.onSelectUnsplashImage(photo.urls.full.toString());
            setState(() => _selectedPhotoIndex = index);
          },
        );
      }).toList(),
    );
  }
}

class _UnsplashImage extends StatelessWidget {
  const _UnsplashImage({
    required this.type,
    required this.photo,
    required this.onTap,
    required this.isSelected,
  });

  final UnsplashImageType type;
  final Photo photo;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    Widget child = switch (type) {
      UnsplashImageType.halfScreen => _buildHalfScreenImage(context),
      UnsplashImageType.fullScreen => _buildFullScreenImage(context),
    };

    if (isSelected) {
      child = Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.borderColorScheme.themeThick,
            width: 2.0,
          ),
          borderRadius: BorderRadius.circular(theme.spacing.s),
        ),
        padding: EdgeInsets.all(2.0),
        child: child,
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: child,
      ),
    );
  }

  Widget _buildHalfScreenImage(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Image.network(
            photo.urls.thumb.toString(),
            fit: BoxFit.cover,
          ),
        ),
        const HSpace(2.0),
        FlowyText('by ${photo.name}', fontSize: 10.0),
      ],
    );
  }

  Widget _buildFullScreenImage(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(theme.spacing.xs),
      child: Image.network(
        photo.urls.thumb.toString(),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }
}

extension on Photo {
  String get name {
    if (user.username.isNotEmpty) {
      return user.username;
    }
    if (user.name.isNotEmpty) {
      return user.name;
    }
    if (user.email?.isNotEmpty == true) {
      return user.email!;
    }

    return user.id;
  }
}
