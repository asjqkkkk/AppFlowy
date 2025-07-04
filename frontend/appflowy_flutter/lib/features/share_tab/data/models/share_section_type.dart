import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';

/// The type of the shared section.
///
/// - public: the shared section is public, anyone in the workspace can view/edit it.
/// - shared: the shared section is shared, anyone in the shared section can view/edit it.
/// - private: the shared section is private, only the users in the shared section can view/edit it.
enum SharedSectionType {
  unknown,
  public,
  shared,
  private;
}

extension SharedSectionTypeExtension on SharedViewSectionPB {
  SharedSectionType get shareSectionType {
    switch (this) {
      case SharedViewSectionPB.PublicSection:
        return SharedSectionType.public;
      case SharedViewSectionPB.SharedSection:
        return SharedSectionType.shared;
      case SharedViewSectionPB.PrivateSection:
        return SharedSectionType.private;
      default:
        return SharedSectionType.unknown;
    }
  }
}
