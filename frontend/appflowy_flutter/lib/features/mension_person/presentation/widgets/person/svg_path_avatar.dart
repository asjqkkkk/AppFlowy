import 'package:flutter/widgets.dart';
import 'package:path_drawing/path_drawing.dart';

class CustomAvatarClipper extends CustomClipper<Path> {
  CustomAvatarClipper({this.path = avatarPath});

  final String path;

  @override
  Path getClip(Size size) => parseSvgPathData(path);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class PathWidgetMask extends StatelessWidget {
  const PathWidgetMask({
    super.key,
    required this.child,
    this.path = avatarPath,
  });

  final Widget child;
  final String path;

  @override
  Widget build(BuildContext context) =>
      ClipPath(clipper: CustomAvatarClipper(path: path), child: child);
}

const avatarPath =
    'M90 45C90 73.2278 73.2278 90 45 90C16.7722 90 0 73.2278 0 45C0 16.7722 16.7722 0 45 0C73.2278 0 90 16.7722 90 45Z';
const avatarContainerPath =
    'M100 50C100 81.3642 81.3642 100 50 100C18.6358 100 0 81.3642 0 50C0 18.6358 18.6358 0 50 0C81.3642 0 100 18.6358 100 50Z';
