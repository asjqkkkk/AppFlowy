import 'package:appflowy/user/application/user_listener.dart';
import 'package:appflowy/workspace/application/home/home_event.dart';
import 'package:appflowy/workspace/application/home/home_state.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-error/code.pbenum.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:flowy_infra/uuid.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'home_event.dart';
export 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc(String workspaceId)
      : _workspaceListener = FolderListener(
          workspaceId: workspaceId,
        ),
        super(HomeState.initial(workspaceId)) {
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
        add(const HomeEvent.refreshLatestView());
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
        (error) {
          Log.error(error);
          // This should rarely happen now since backend returns WorkspaceLatestPB with error_code
          emit(
            state.copyWith(
              pageError: error,
            ),
          );
        },
      );
    });
  }

  void _onDidReceiveWorkspaceSetting(
    HomeDidReceiveWorkspaceSettingEvent event,
    Emitter<HomeState> emit,
  ) {
    final setting = event.setting;

    // Check if there's an error code in the workspace setting
    if (setting.hasPageError()) {
      final errorCodeValue = setting.pageError;
      final errorCode = ErrorCode.valueOf(errorCodeValue);
      if (errorCode != null) {
        // Create a FlowyError from the error code
        final error = FlowyError()
          ..code = errorCode
          ..msg = uuid().toString();

        emit(
          state.copyWith(
            pageError: error,
            clearLatestView: true, // Explicitly clear the latest view
          ),
        );
        return;
      }
    }

    final latestView = setting.latestView;
    if (latestView.isSpace) {
      // If the latest view is a space, we don't need to open it.
      return;
    }

    emit(
      state.copyWith(
        latestView: latestView,
        clearPageError: true, // Clear any previous page error
      ),
    );
  }
}
