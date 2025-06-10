import 'package:appflowy/features/share_tab/data/models/share_access_level.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';

typedef SharedPages = List<SharedPage>;

class SharedPage {
  SharedPage({
    required this.view,
    required this.accessLevel,
  });

  final ViewPB view;
  final ShareAccessLevel accessLevel;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SharedPage &&
        other.view == view &&
        other.accessLevel == accessLevel;
  }

  @override
  int get hashCode => Object.hash(view, accessLevel);

  @override
  String toString() {
    return 'SharedPage(view: $view, accessLevel: $accessLevel)';
  }
}

class SharedPageResponse {
  SharedPageResponse({
    required this.sharedPages,
    required this.noAccessViewIds,
  });

  final SharedPages sharedPages;
  final List<String> noAccessViewIds;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SharedPageResponse &&
        other.sharedPages == sharedPages &&
        other.noAccessViewIds == noAccessViewIds;
  }

  @override
  int get hashCode => Object.hash(sharedPages, noAccessViewIds);

  @override
  String toString() {
    return 'SharedPageResponse(sharedPages: $sharedPages, noAccessViewIds: $noAccessViewIds)';
  }
}
