import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:equatable/equatable.dart';

enum ImportErrorCode {
  fileSizeExceeded,
  invalidFileFormat,
  fileNotFound,
  fileEmpty,
  importFailed,
  unknown,
}

class ImportError extends Equatable {
  const ImportError({
    required this.code,
    required this.message,
    this.fileName,
    this.maxSizeLimit,
  });

  factory ImportError.fileSizeExceeded({
    required String fileName,
    required String maxSizeLimit,
  }) {
    return ImportError(
      code: ImportErrorCode.fileSizeExceeded,
      message: LocaleKeys.workspaceImport_errors_fileSizeExceedsMaximum.tr(),
      fileName: fileName,
      maxSizeLimit: maxSizeLimit,
    );
  }

  factory ImportError.invalidFileFormat({
    required String fileName,
  }) {
    return ImportError(
      code: ImportErrorCode.invalidFileFormat,
      message: LocaleKeys.workspaceImport_errors_invalidFileFormat.tr(),
      fileName: fileName,
    );
  }

  factory ImportError.fileNotFound({
    required String fileName,
  }) {
    return ImportError(
      code: ImportErrorCode.fileNotFound,
      message: LocaleKeys.workspaceImport_errors_fileNotExist.tr(),
      fileName: fileName,
    );
  }

  factory ImportError.fileEmpty({
    required String fileName,
  }) {
    return ImportError(
      code: ImportErrorCode.fileEmpty,
      message: LocaleKeys.workspaceImport_errors_fileIsEmpty.tr(),
      fileName: fileName,
    );
  }

  factory ImportError.importFailed({
    String? fileName,
    String? details,
  }) {
    return ImportError(
      code: ImportErrorCode.importFailed,
      message: details ??
          LocaleKeys.workspaceImport_errors_failedToImportWorkspace.tr(),
      fileName: fileName,
    );
  }

  factory ImportError.unknown({
    String? message,
    String? fileName,
  }) {
    return ImportError(
      code: ImportErrorCode.unknown,
      message: message ?? LocaleKeys.workspaceImport_errors_unknownError.tr(),
      fileName: fileName,
    );
  }

  final ImportErrorCode code;
  final String message;
  final String? fileName;
  final String? maxSizeLimit;

  @override
  List<Object?> get props => [code, message, fileName, maxSizeLimit];
}
