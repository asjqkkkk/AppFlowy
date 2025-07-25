import 'dart:async';

import 'package:appflowy/features/export/data/repositories/rust_workspace_export_repository_impl.dart';
import 'package:appflowy/features/export/data/repositories/workspace_export_repository.dart';
import 'package:appflowy/features/export/logic/workspace_export_event.dart';
import 'package:appflowy/features/export/logic/workspace_export_state.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:bloc/bloc.dart';

export 'workspace_export_event.dart';
export 'workspace_export_state.dart';

class WorkspaceExportBloc
    extends Bloc<WorkspaceExportEvent, WorkspaceExportState> {
  WorkspaceExportBloc({
    required String workspaceId,
    WorkspaceExportRepository? exportRepository,
  })  : exportRepository =
            exportRepository ?? RustWorkspaceExportRepositoryImpl(),
        super(WorkspaceExportState.initial(workspaceId)) {
    on<WorkspaceExportInitialEvent>(_onInitial);
    on<WorkspaceExportStartEvent>(_onStartExport);
  }

  final WorkspaceExportRepository exportRepository;

  Future<void> _onInitial(
    WorkspaceExportInitialEvent event,
    Emitter<WorkspaceExportState> emit,
  ) async {
    emit(
      state.copyWith(
        workspaceId: event.workspaceId,
        isLoading: false,
        isExporting: false,
      ),
    );
  }

  Future<void> _onStartExport(
    WorkspaceExportStartEvent event,
    Emitter<WorkspaceExportState> emit,
  ) async {
    emit(
      state.copyWith(
        isLoading: true,
        isExporting: true,
        exportPath: event.exportPath,
        exportName: event.exportName,
      ),
    );

    try {
      final result = await exportRepository.exportWorkspace(
        workspaceId: event.workspaceId,
        exportPath: event.exportPath,
        exportName: event.exportName,
      );

      emit(
        state.copyWith(
          isLoading: false,
          isExporting: false,
          exportResult: result,
        ),
      );

      result.fold(
        (progress) => Log.info('Workspace export completed successfully'),
        (error) => Log.error('Workspace export failed: $error'),
      );
    } catch (error) {
      Log.error('Workspace export error: $error');
      emit(
        state.copyWith(
          isLoading: false,
          isExporting: false,
          exportResult: FlowyResult.failure(
            FlowyError(msg: error.toString()),
          ),
        ),
      );
    }
  }
}
