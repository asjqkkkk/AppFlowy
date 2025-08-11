import 'dart:async';
import 'dart:io';

import 'package:appflowy/core/helpers/url_launcher.dart';
import 'package:appflowy/features/workspace_import/data/models/import_error.dart';
import 'package:appflowy/features/workspace_import/data/models/import_file_data.dart';
import 'package:appflowy/features/workspace_import/data/repositories/workspace_import_repository.dart';
import 'package:appflowy/features/workspace_import/logic/workspace_import_dialog_event.dart';
import 'package:appflowy/features/workspace_import/logic/workspace_import_dialog_state.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_backend/log.dart';
import 'package:bloc/bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

export 'workspace_import_dialog_event.dart';
export 'workspace_import_dialog_state.dart';

class WorkspaceImportDialogBloc
    extends Bloc<WorkspaceImportDialogEvent, WorkspaceImportDialogState> {
  WorkspaceImportDialogBloc({
    required this.importRepository,
  }) : super(WorkspaceImportDialogState.initial()) {
    on<WorkspaceImportDialogInitialized>(_onInitialized);
    on<FileDropped>(_onFileDropped);
    on<UploadButtonClicked>(_onUploadButtonClicked);
    on<FileSelected>(_onFileSelected);
    on<LearnMoreClicked>(_onLearnMoreClicked);
    on<DragEntered>(_onDragEntered);
    on<DragExited>(_onDragExited);
    on<ImportCompleted>(_onImportCompleted);
  }

  final WorkspaceImportRepository importRepository;

  Future<void> _onInitialized(
    WorkspaceImportDialogInitialized event,
    Emitter<WorkspaceImportDialogState> emit,
  ) async {
    emit(WorkspaceImportDialogState.initial());
  }

  Future<void> _onFileDropped(
    FileDropped event,
    Emitter<WorkspaceImportDialogState> emit,
  ) async {
    await _handleFile(event.file, emit);
  }

  Future<void> _onUploadButtonClicked(
    UploadButtonClicked event,
    Emitter<WorkspaceImportDialogState> emit,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.first.path;
        if (filePath != null) {
          final file = File(filePath);
          await _handleFile(file, emit);
        }
      }
    } on PlatformException catch (e) {
      Log.error('Failed to pick file: $e');
      emit(
        state.copyWith(
          status: WorkspaceImportDialogStatus.error,
          error: ImportError.unknown(
            message: LocaleKeys.workspaceImport_errors_failedToPickFile
                .tr(args: [e.message ?? '']),
          ),
        ),
      );
    }
  }

  Future<void> _onFileSelected(
    FileSelected event,
    Emitter<WorkspaceImportDialogState> emit,
  ) async {
    await _handleFile(event.file, emit);
  }

  Future<void> _onLearnMoreClicked(
    LearnMoreClicked event,
    Emitter<WorkspaceImportDialogState> emit,
  ) async {
    await afLaunchUrlString(
      'https://appflowy.com/guide/import-from-AppFlowy',
    );
  }

  Future<void> _onDragEntered(
    DragEntered event,
    Emitter<WorkspaceImportDialogState> emit,
  ) async {
    if (state.status == WorkspaceImportDialogStatus.idle) {
      emit(state.copyWith(status: WorkspaceImportDialogStatus.dragOver));
    }
  }

  Future<void> _onDragExited(
    DragExited event,
    Emitter<WorkspaceImportDialogState> emit,
  ) async {
    if (state.status == WorkspaceImportDialogStatus.dragOver) {
      emit(state.copyWith(status: WorkspaceImportDialogStatus.idle));
    }
  }

  Future<void> _handleFile(
    File file,
    Emitter<WorkspaceImportDialogState> emit,
  ) async {
    emit(state.copyWith(status: WorkspaceImportDialogStatus.validating));

    try {
      final fileStats = await file.stat();
      final fileName = file.path.split('/').last;

      final isZipFile = fileName.toLowerCase().endsWith('.zip');
      final exists = await file.exists();

      ImportError? error;
      if (!exists) {
        error = ImportError.fileNotFound(fileName: fileName);
      } else if (!isZipFile) {
        error = ImportError.invalidFileFormat(fileName: fileName);
      } else if (fileStats.size == 0) {
        error = ImportError.fileEmpty(fileName: fileName);
      } else if (fileStats.size > 200 * 1024 * 1024) {
        error = ImportError.fileSizeExceeded(
          fileName: fileName,
          maxSizeLimit: LocaleKeys.workspaceImport_sizeLimit200MB.tr(),
        );
      }

      final fileData = ImportFileData(
        file: file,
        name: fileName,
        size: fileStats.size,
        isValid: error == null,
        errorMessage: error?.message,
      );

      if (error != null) {
        emit(
          state.copyWith(
            status: WorkspaceImportDialogStatus.error,
            error: error,
          ),
        );
        emit(WorkspaceImportDialogState.initial());
      } else {
        emit(
          state.copyWith(
            status: WorkspaceImportDialogStatus.uploading,
            selectedFile: fileData,
          ),
        );

        final result = await importRepository.importWorkspace(
          archivePath: fileData.file.path,
          workspaceName: fileData.name,
        );

        emit(
          state.copyWith(status: WorkspaceImportDialogStatus.importProgress),
        );

        result.fold(
          (_) {
            emit(state.copyWith(status: WorkspaceImportDialogStatus.success));
          },
          (error) {
            emit(
              state.copyWith(
                status: WorkspaceImportDialogStatus.error,
                error: ImportError.importFailed(
                  fileName: state.selectedFile?.name,
                  details: error.toString(),
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      Log.error('Failed to validate file: $e');
      emit(
        state.copyWith(
          status: WorkspaceImportDialogStatus.error,
          error: ImportError.unknown(
            message: LocaleKeys.workspaceImport_errors_failedToValidateFile
                .tr(args: [e.toString()]),
          ),
        ),
      );
    }
  }

  Future<void> _onImportCompleted(
    ImportCompleted event,
    Emitter<WorkspaceImportDialogState> emit,
  ) async {
    if (event.success) {
      emit(state.copyWith(status: WorkspaceImportDialogStatus.success));
    } else {
      emit(
        state.copyWith(
          status: WorkspaceImportDialogStatus.error,
          error: ImportError.importFailed(),
        ),
      );
    }
  }
}
