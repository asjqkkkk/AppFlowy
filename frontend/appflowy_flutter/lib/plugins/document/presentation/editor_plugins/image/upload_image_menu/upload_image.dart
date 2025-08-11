import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/shared/patterns/file_type_patterns.dart';
import 'package:appflowy/shared/permission/permission_checker.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/util/default_extensions.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/file_picker/file_picker_service.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:universal_platform/universal_platform.dart';

class UploadImageButton extends StatelessWidget {
  const UploadImageButton({
    super.key,
    required this.onPickFiles,
    this.allowedExtensions = defaultImageExtensions,
    this.allowMultipleImages = false,
  });

  final void Function(List<XFile>) onPickFiles;
  final List<String> allowedExtensions;
  final bool allowMultipleImages;

  @override
  Widget build(BuildContext context) {
    return AFOutlinedTextButton.normal(
      text: LocaleKeys.document_imageBlock_upload_placeholder.tr(),
      size: AFButtonSize.l,
      onTap: () async {
        final files = await _pickImageFiles(
          context,
          allowedExtensions: allowedExtensions,
          allowMultipleImages: allowMultipleImages,
        );
        if (files.isNotEmpty) {
          onPickFiles(files);
        }
      },
    );
  }
}

class FileDropZone extends StatefulWidget {
  const FileDropZone({
    super.key,
    required this.onPickFiles,
    this.allowedExtensions = defaultImageExtensions,
    this.allowMultipleImages = false,
  });

  final void Function(List<XFile>) onPickFiles;
  final List<String> allowedExtensions;
  final bool allowMultipleImages;

  @override
  State<FileDropZone> createState() => _FileDropZoneState();
}

class _FileDropZoneState extends State<FileDropZone> {
  bool isHovered = false;
  bool isDragging = false;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return GestureDetector(
      onTap: () async {
        final files = await _pickImageFiles(
          context,
          allowedExtensions: widget.allowedExtensions,
          allowMultipleImages: widget.allowMultipleImages,
        );

        widget.onPickFiles(files);
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => isHovered = true),
        onExit: (_) => setState(() => isHovered = false),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDragging
                ? theme.fillColorScheme.infoLight
                : isHovered
                    ? theme.surfaceColorScheme.primaryHover
                    : theme.surfaceColorScheme.primary,
            borderRadius: BorderRadius.circular(theme.spacing.m),
          ),
          child: DottedBorder(
            dashPattern: [theme.spacing.xs],
            strokeWidth: 2.0,
            radius: Radius.circular(theme.spacing.m),
            borderType: BorderType.RRect,
            color: isDragging
                ? theme.borderColorScheme.themeThick
                : isHovered
                    ? theme.borderColorScheme.primaryHover
                    : theme.borderColorScheme.primary,
            child: DropTarget(
              onDragEntered: (_) => setState(() => isDragging = true),
              onDragExited: (_) => setState(() => isDragging = false),
              onDragDone: onDragDone,
              child: Center(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: LocaleKeys.document_plugins_file_fileUploadHint
                            .tr(),
                        style: theme.textStyle.body.standard(
                          color: theme.textColorScheme.primary,
                        ),
                      ),
                      TextSpan(
                        text: LocaleKeys
                            .document_plugins_file_fileUploadHintSuffix
                            .tr(),
                        style: theme.textStyle.body.standard(
                          color: theme.textColorScheme.action,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void onDragDone(details) {
    if (details.files.isEmpty) {
      return;
    }

    final imageFiles = details.files.where(
      (file) {
        if (file.mimeType?.startsWith('image/') ?? false) {
          return true;
        }
        if (file.name.endsWith('.svg')) {
          return true;
        }
        if (imgExtensionRegex.hasMatch(file.name)) {
          return true;
        }
        return false;
      },
    ).toList();

    if (imageFiles.isEmpty) {
      showToastNotification(
        message: LocaleKeys.document_plugins_file_noImages.tr(),
        type: ToastificationType.error,
      );
      return;
    }

    widget.onPickFiles(imageFiles);
  }
}

Future<List<XFile>> _pickImageFiles(
  BuildContext context, {
  required List<String> allowedExtensions,
  required bool allowMultipleImages,
}) async {
  if (UniversalPlatform.isDesktopOrWeb) {
    final result = await getIt<FilePickerService>().pickFiles(
      dialogTitle: '',
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      allowMultiple: allowMultipleImages,
    );
    if (result == null) {
      return [];
    }
    return result.files.map((f) => f.xFile).toList();
  }

  final photoPermission = await PermissionChecker.checkPhotoPermission(context);

  if (!photoPermission) {
    Log.error('Has no permission to access the photo library');
    return [];
  }

  return ImagePicker().pickMultiImage();
}
