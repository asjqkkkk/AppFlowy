import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:appflowy_result/appflowy_result.dart';

class FavoriteService {
  Future<FlowyResult<RepeatedFavoriteViewPB, FlowyError>> readFavorites() {
    final result = FolderEventReadFavorites().send();
    return result.then((result) {
      return result.fold(
        (favoriteViews) {
          return FlowyResult.success(
            RepeatedFavoriteViewPB(
              items: favoriteViews.items.where((e) => !e.item.isSpace),
            ),
          );
        },
        (error) => FlowyResult.failure(error),
      );
    });
  }

  Future<FlowyResult<void, FlowyError>> toggleFavorite(String viewId) async {
    final id = RepeatedViewIdPB.create()..items.add(viewId);
    return FolderEventToggleFavorite(id).send();
  }

  Future<FlowyResult<void, FlowyError>> pinFavorite(ViewPB view) async {
    return pinOrUnpinFavorite(view, true);
  }

  Future<FlowyResult<void, FlowyError>> unpinFavorite(ViewPB view) async {
    return pinOrUnpinFavorite(view, false);
  }

  Future<FlowyResult<void, FlowyError>> pinOrUnpinFavorite(
    ViewPB view,
    bool isPinned,
  ) async {
    final payload = PinOrUnpinFavoritePayloadPB()
      ..viewId = view.id
      ..isPinned = isPinned;
    return FolderEventPinOrUnpinFavorite(payload).send();
  }
}
