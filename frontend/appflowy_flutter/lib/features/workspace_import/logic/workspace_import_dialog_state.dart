import 'package:appflowy/features/workspace_import/data/models/import_error.dart';
import 'package:appflowy/features/workspace_import/data/models/import_file_data.dart';
import 'package:equatable/equatable.dart';

enum WorkspaceImportDialogStatus {
  idle,
  dragOver,
  validating,
  uploading,
  importProgress,
  success,
  error,
}

class WorkspaceImportDialogState extends Equatable {
  const WorkspaceImportDialogState({
    required this.status,
    this.selectedFile,
    this.error,
    this.uploadProgress,
  });

  factory WorkspaceImportDialogState.initial() {
    return const WorkspaceImportDialogState(
      status: WorkspaceImportDialogStatus.idle,
    );
  }

  final WorkspaceImportDialogStatus status;
  final ImportFileData? selectedFile;
  final ImportError? error;
  final double? uploadProgress;

  bool get isLoading =>
      status == WorkspaceImportDialogStatus.validating ||
      status == WorkspaceImportDialogStatus.uploading;

  bool get hasFile => selectedFile != null;

  bool get canImport =>
      hasFile &&
      selectedFile!.isValid &&
      status == WorkspaceImportDialogStatus.idle;

  WorkspaceImportDialogState copyWith({
    WorkspaceImportDialogStatus? status,
    ImportFileData? selectedFile,
    ImportError? error,
    double? uploadProgress,
  }) {
    return WorkspaceImportDialogState(
      status: status ?? this.status,
      selectedFile: selectedFile ?? this.selectedFile,
      error: error ?? this.error,
      uploadProgress: uploadProgress ?? this.uploadProgress,
    );
  }

  WorkspaceImportDialogState clearFile() {
    return WorkspaceImportDialogState(
      status: WorkspaceImportDialogStatus.idle,
    );
  }

  @override
  List<Object?> get props => [
        status,
        selectedFile,
        error,
        uploadProgress,
      ];
}
