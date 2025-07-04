import 'package:appflowy/user/application/user_listener.dart';
import 'package:appflowy/workspace/application/home/home_event.dart';
import 'package:appflowy/workspace/application/home/home_state.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/workspace.pb.dart'
    show WorkspaceLatestPB;
import 'package:flutter_bloc/flutter_bloc.dart';

export 'home_event.dart';
export 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc(WorkspaceLatestPB workspaceSetting)
      : _workspaceListener = FolderListener(
          workspaceId: workspaceSetting.workspaceId,
        ),
        super(HomeState.initial(workspaceSetting)) {
    on<HomeInitialEvent>(_onInitial);
    on<HomeShowLoadingEvent>(_onShowLoading);
    on<HomeDidReceiveWorkspaceSettingEvent>(_onDidReceiveWorkspaceSetting);
    on<HomeRefreshLatestViewEvent>(_onRefreshLatestView);
  }

  final FolderListener _workspaceListener;

  @override
  Future<void> close() async {
    await _workspaceListener.stop();
    return super.close();
  }

  Future<void> _onInitial(
    HomeInitialEvent event,
    Emitter<HomeState> emit,
  ) async {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!isClosed) {
        add(HomeEvent.didReceiveWorkspaceSetting(state.workspaceSetting));
      }
    });

    _workspaceListener.start(
      onLatestUpdated: (result) {
        result.fold(
          (latest) => add(HomeEvent.didReceiveWorkspaceSetting(latest)),
          (r) => Log.error(r),
        );
      },
    );
  }

  Future<void> _onShowLoading(
    HomeShowLoadingEvent event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(isLoading: event.isLoading));
  }

  Future<void> _onRefreshLatestView(
    HomeRefreshLatestViewEvent event,
    Emitter<HomeState> emit,
  ) async {
    await FolderEventGetCurrentWorkspaceSetting().send().then((result) {
      result.fold(
        (latest) => add(HomeEvent.didReceiveWorkspaceSetting(latest)),
        (r) => Log.error(r),
      );
    });
  }

  void _onDidReceiveWorkspaceSetting(
    HomeDidReceiveWorkspaceSettingEvent event,
    Emitter<HomeState> emit,
  ) {
    final latestView = event.setting.hasLatestView()
        ? event.setting.latestView
        : state.latestView;

    if (latestView != null && latestView.isSpace) {
      // If the latest view is a space, we don't need to open it.
      return;
    }

    emit(
      state.copyWith(
        workspaceSetting: event.setting,
        latestView: latestView,
      ),
    );
  }
}
