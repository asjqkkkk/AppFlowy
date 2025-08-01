import 'dart:async';

import 'package:appflowy/workspace/application/recent/cached_recent_service.dart';
import 'package:appflowy/workspace/application/recent/recent_listener.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'recent_views_bloc.freezed.dart';

class RecentViewsBloc extends Bloc<RecentViewsEvent, RecentViewsState> {
  RecentViewsBloc() : super(RecentViewsState.initial()) {
    _dispatch();
  }

  RecentViewsListener? _listener;

  void _dispatch() {
    on<RecentViewsEvent>(
      (event, emit) async {
        await event.map(
          initial: (e) async {
            unawaited(_initRecentViewListener());
            add(const RecentViewsEvent.fetchRecentViews());
          },
          addRecentViews: (e) async {
            await updateRecentViews(e.viewIds, true);
          },
          removeRecentViews: (e) async {
            await removeRecentViews(e.viewIds);
          },
          fetchRecentViews: (e) async {
            emit(
              state.copyWith(
                isLoading: false,
                views: await readRecentViews(),
              ),
            );
          },
          hoverView: (e) async {
            emit(
              state.copyWith(hoveredView: e.view),
            );
          },
        );
      },
    );
  }

  Future<void> _initRecentViewListener() async {
    final workspaceResult = await FolderEventReadCurrentWorkspace().send();
    final workspaceId = workspaceResult.fold((w) => w.id, (_) => null);
    if (workspaceId == null) {
      return;
    }

    _listener = RecentViewsListener(workspaceId: workspaceId);
    _listener?.start(
      recentViewsUpdated: (viewIds) {
        if (isClosed) return;

        add(RecentViewsEvent.fetchRecentViews());
      },
    );
  }
}

@freezed
class RecentViewsEvent with _$RecentViewsEvent {
  const factory RecentViewsEvent.initial() = Initial;
  const factory RecentViewsEvent.addRecentViews(List<String> viewIds) =
      AddRecentViews;
  const factory RecentViewsEvent.removeRecentViews(List<String> viewIds) =
      RemoveRecentViews;
  const factory RecentViewsEvent.fetchRecentViews() = FetchRecentViews;
  const factory RecentViewsEvent.hoverView(ViewPB view) = HoverView;
}

@freezed
class RecentViewsState with _$RecentViewsState {
  const factory RecentViewsState({
    required List<SectionViewPB> views,
    @Default(true) bool isLoading,
    @Default(null) ViewPB? hoveredView,
  }) = _RecentViewsState;

  factory RecentViewsState.initial() => const RecentViewsState(views: []);
}
