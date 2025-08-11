import 'package:appflowy/plugins/document/presentation/editor_plugins/plugins.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';

extension IntoCoverTypePB on CoverType {
  CoverTypePB into() => switch (this) {
        CoverType.color => CoverTypePB.ColorCover,
        CoverType.gradient => CoverTypePB.GradientCover,
        CoverType.asset => CoverTypePB.AssetCover,
        CoverType.file => CoverTypePB.FileCover,
        _ => CoverTypePB.FileCover,
      };
}

extension IntoCoverTypeExt on CoverTypePB {
  CoverType into() => switch (this) {
        CoverTypePB.ColorCover => CoverType.color,
        CoverTypePB.GradientCover => CoverType.gradient,
        CoverTypePB.AssetCover => CoverType.asset,
        CoverTypePB.FileCover => CoverType.file,
        _ => CoverType.file,
      };
}
