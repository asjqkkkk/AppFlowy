import 'package:appflowy/features/profile_setting/data/banner.dart';
import 'package:appflowy/features/profile_setting/logic/profile_setting_bloc.dart';
import 'package:appflowy/features/profile_setting/logic/profile_setting_event.dart';
import 'package:appflowy/features/profile_setting/presentation/widgets/banner_widget.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/image/image_util.dart';
import 'package:appflowy/shared/patterns/file_type_patterns.dart';
import 'package:appflowy/shared/permission/permission_checker.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

class MobileBannerUploader extends StatelessWidget {
  const MobileBannerUploader({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ProfileSettingBloc>(),
        profile = bloc.state.profile,
        customBanner = profile.customBanner,
        selected = customBanner == profile.banner;
    if (customBanner == null) {
      return buildUploadArea(context);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        bloc.add(ProfileSettingEvent.selectBanner(customBanner));
      },
      child: SizedBox(
        height: 120,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            NetworkImageBannerWidget(
              size: Size(double.infinity, 120),
              banner: customBanner,
              selected: selected,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildUploadArea(BuildContext context) {
    final theme = AppFlowyTheme.of(context),
        style =
            theme.textStyle.body.standard(color: theme.textColorScheme.primary);
    return SizedBox(
      height: 120,
      width: double.infinity,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => pickAndUploadImage(context),
        child: DottedBorder(
          dashPattern: const [3, 3],
          radius: const Radius.circular(8),
          borderType: BorderType.RRect,
          color: Theme.of(context).hintColor,
          child: Center(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: LocaleKeys.settings_profilePage_pressTo.tr(),
                    style: style,
                  ),
                  TextSpan(
                    text: ' ${LocaleKeys.settings_profilePage_upload.tr()} ',
                    style: style.copyWith(color: theme.textColorScheme.action),
                  ),
                  TextSpan(
                    text: LocaleKeys.settings_profilePage_anImage.tr(),
                    style: style,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pickAndUploadImage(BuildContext context) async {
    if (!context.mounted) return;
    final photoPermission =
        await PermissionChecker.checkPhotoPermission(context);
    if (!photoPermission) {
      Log.error(
        'Has no permission to access the photo library while uploading custom image',
      );
      return;
    }
    // on mobile, the users can pick a image file from camera or image library
    final files = await ImagePicker().pickMultiImage();
    final imageFiles = files
        .where(
          (file) =>
              file.mimeType?.startsWith('image/') ??
              false ||
                  imgExtensionRegex.hasMatch(file.name) ||
                  file.name.endsWith('.svg'),
        )
        .toList();
    if (imageFiles.isEmpty || !context.mounted) return;
    await uploadImage(imageFiles.first.path, context);
  }

  Future<void> uploadImage(String path, BuildContext context) async {
    final bloc = context.read<ProfileSettingBloc>();
    final (url, errorMsg) = await saveImageToCloudStorage(
      path,
      bloc.workspace?.workspaceId ?? '',
    );
    if (errorMsg?.isNotEmpty ?? false) {
      Log.error('upload icon image :$path error :$errorMsg');
      return;
    }
    if (url?.isEmpty ?? true) return;
    bloc.add(ProfileSettingEvent.uploadBanner(NetworkImageBanner(url: url!)));
  }
}
