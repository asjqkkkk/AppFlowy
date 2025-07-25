import 'dart:io';

import 'package:equatable/equatable.dart';

abstract class WorkspaceImportDialogEvent extends Equatable {
  const WorkspaceImportDialogEvent();

  @override
  List<Object?> get props => [];
}

class WorkspaceImportDialogInitialized extends WorkspaceImportDialogEvent {
  const WorkspaceImportDialogInitialized();
}

class FileDropped extends WorkspaceImportDialogEvent {
  const FileDropped(this.file);

  final File file;

  @override
  List<Object?> get props => [file];
}

class UploadButtonClicked extends WorkspaceImportDialogEvent {
  const UploadButtonClicked();
}

class FileSelected extends WorkspaceImportDialogEvent {
  const FileSelected(this.file);

  final File file;

  @override
  List<Object?> get props => [file];
}

class CloseButtonClicked extends WorkspaceImportDialogEvent {
  const CloseButtonClicked();
}

class LearnMoreClicked extends WorkspaceImportDialogEvent {
  const LearnMoreClicked();
}

class DragEntered extends WorkspaceImportDialogEvent {
  const DragEntered();
}

class DragExited extends WorkspaceImportDialogEvent {
  const DragExited();
}

class ImportCompleted extends WorkspaceImportDialogEvent {
  const ImportCompleted({required this.success});

  final bool success;

  @override
  List<Object?> get props => [success];
}
