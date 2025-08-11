import 'package:appflowy/mobile/application/page_style/document_page_style_bloc.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy/workspace/application/view/view_listener.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../shared/icon_emoji_picker/flowy_icon_emoji_picker.dart';

class DocumentImmersiveCoverBloc
    extends Bloc<DocumentImmersiveCoverEvent, DocumentImmersiveCoverState> {
  DocumentImmersiveCoverBloc({
    required ViewPB view,
  })  : _viewId = view.id,
        _viewListener = ViewListener(viewId: view.id),
        super(DocumentImmersiveCoverState.initial(view)) {
    on<_Initial>(_onInitial);
    on<_UpdateCoverAndIcon>(_onUpdateCoverAndIcon);
  }

  final String _viewId;
  final ViewListener? _viewListener;

  @override
  Future<void> close() {
    _viewListener?.stop();
    return super.close();
  }

  Future<void> _onInitial(
    _Initial event,
    Emitter<DocumentImmersiveCoverState> emit,
  ) async {
    await ViewBackendService.getView(_viewId).fold(
      (view) {
        if (!isClosed) {
          final cover = view.cover ?? PageStyleCover.none();
          final icon = EmojiIconData.fromViewIconPB(view.icon);
          emit(
            DocumentImmersiveCoverState(
              cover: cover,
              icon: icon,
              name: view.name,
            ),
          );
        }
      },
      Log.error,
    );

    _viewListener?.start(
      onViewUpdated: (view) {
        add(
          DocumentImmersiveCoverEvent.updateCoverAndIcon(
            view.cover,
            EmojiIconData.fromViewIconPB(view.icon),
            view.name,
          ),
        );
      },
    );
  }

  void _onUpdateCoverAndIcon(
    _UpdateCoverAndIcon event,
    Emitter<DocumentImmersiveCoverState> emit,
  ) {
    emit(
      state.copyWith(
        icon: event.icon,
        cover: event.cover ?? state.cover,
        name: event.name ?? state.name,
      ),
    );
  }
}

sealed class DocumentImmersiveCoverEvent {
  const DocumentImmersiveCoverEvent();

  const factory DocumentImmersiveCoverEvent.initial() = _Initial;
  const factory DocumentImmersiveCoverEvent.updateCoverAndIcon(
    PageStyleCover? cover,
    EmojiIconData? icon,
    String? name,
  ) = _UpdateCoverAndIcon;
}

class _Initial extends DocumentImmersiveCoverEvent {
  const _Initial();
}

class _UpdateCoverAndIcon extends DocumentImmersiveCoverEvent {
  const _UpdateCoverAndIcon(this.cover, this.icon, this.name);

  final PageStyleCover? cover;
  final EmojiIconData? icon;
  final String? name;
}

class DocumentImmersiveCoverState extends Equatable {
  const DocumentImmersiveCoverState({
    this.icon,
    required this.cover,
    this.name = '',
  });

  factory DocumentImmersiveCoverState.initial(ViewPB view) {
    return DocumentImmersiveCoverState(
      cover: view.cover ?? PageStyleCover.none(),
      icon: EmojiIconData.fromViewIconPB(view.icon),
      name: view.name,
    );
  }

  final EmojiIconData? icon;
  final PageStyleCover cover;
  final String name;

  DocumentImmersiveCoverState copyWith({
    EmojiIconData? icon,
    PageStyleCover? cover,
    String? name,
  }) {
    return DocumentImmersiveCoverState(
      icon: icon ?? this.icon,
      cover: cover ?? this.cover,
      name: name ?? this.name,
    );
  }

  @override
  List<Object?> get props => [icon, cover, name];
}
