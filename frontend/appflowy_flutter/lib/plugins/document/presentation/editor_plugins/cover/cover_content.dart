import 'dart:io';

import 'package:appflowy/mobile/application/page_style/document_page_style_bloc.dart';
import 'package:appflowy/shared/appflowy_network_image.dart';
import 'package:appflowy/shared/flowy_gradient_colors.dart';
import 'package:appflowy/shared/flowy_tint_colors.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

class CoverContent extends StatelessWidget {
  const CoverContent({
    super.key,
    required this.type,
    required this.value,
    this.width,
    this.height,
    this.userProfile,
    this.fallback,
  });

  final PageStyleCoverImageType type;
  final String value;
  final UserProfilePB? userProfile;
  final double? width;
  final double? height;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    return switch (type) {
      PageStyleCoverImageType.customImage ||
      PageStyleCoverImageType.unsplashImage =>
        SizedBox(
          width: width,
          height: height,
          child: FlowyNetworkImage(
            url: value,
            userProfilePB: userProfile,
          ),
        ),
      PageStyleCoverImageType.builtInImage => SizedBox(
          width: width,
          height: height,
          child: Image.asset(
            PageStyleCoverImageType.builtInImagePath(value),
            fit: BoxFit.cover,
          ),
        ),
      PageStyleCoverImageType.pureColor => Container(
          width: width,
          height: height,
          color: FlowyTint.fromId(value)?.color(context) ??
              value.tryToColor() ??
              Colors.transparent,
        ),
      PageStyleCoverImageType.gradientColor => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: FlowyGradient.fromId(value)?.toGradient(context),
          ),
        ),
      PageStyleCoverImageType.localImage => SizedBox(
          width: width,
          height: height,
          child: Image.file(
            File(value),
            fit: BoxFit.cover,
          ),
        ),
      _ => fallback ?? SizedBox.shrink(),
    };
  }
}
