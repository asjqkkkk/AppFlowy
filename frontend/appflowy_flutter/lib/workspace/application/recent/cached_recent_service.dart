import 'dart:async';

import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:fixnum/fixnum.dart';

Future<FlowyResult<void, FlowyError>> updateRecentViews(
  List<String> viewIds,
  bool addInRecent,
) async {
  return FolderEventUpdateRecentViews(
    UpdateRecentViewPayloadPB(
      viewIds: viewIds,
      addInRecent: addInRecent,
    ),
  ).send();
}

Future<List<SectionViewPB>> readRecentViews() async {
  final payload = ReadRecentViewsPB(start: Int64(), limit: Int64(100));
  final result = await FolderEventReadRecentViews(payload).send();
  return result.fold(
    (recentViews) {
      return recentViews.items
          .where((e) => !e.item.isSpace && e.item.id != e.item.parentViewId)
          .toList();
    },
    (error) {
      return [];
    },
  );
}

Future<List<SectionViewPB>> removeRecentViews(List<String> viewIds) async {
  throw UnimplementedError();
}
