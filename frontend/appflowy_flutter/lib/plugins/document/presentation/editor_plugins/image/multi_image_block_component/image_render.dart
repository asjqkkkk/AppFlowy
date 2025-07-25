import 'dart:io';

import 'package:appflowy/plugins/document/presentation/editor_plugins/image/common.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/plugins.dart';
import 'package:appflowy/shared/appflowy_network_image.dart';
import 'package:appflowy_backend/protobuf/flowy-user/user_profile.pb.dart';
import 'package:flowy_infra/size.dart';
import 'package:flutter/material.dart';

@visibleForTesting
class ImageRender extends StatelessWidget {
  const ImageRender({
    super.key,
    required this.image,
    this.userProfile,
    this.fit = BoxFit.cover,
    this.borderRadius = Corners.s6Border,
  });

  final ImageBlockData image;
  final UserProfilePB? userProfile;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = normalizeFileUrl(
      context,
      fileId: image.url,
    );
    Widget child;
    if (image.type == CustomImageType.internal ||
        image.type == CustomImageType.external ||
        !File(image.url).existsSync()) {
      child = FlowyNetworkImage(
        url: normalizedUrl,
        userProfilePB: userProfile,
        fit: fit,
      );
    } else {
      child = Image.file(File(image.url), fit: fit);
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: borderRadius),
      child: child,
    );
  }
}
