import 'dart:io';

import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';

class ImportFileData {
  const ImportFileData({
    required this.file,
    required this.name,
    required this.size,
    required this.isValid,
    this.errorMessage,
  });

  final File file;
  final String name;
  final int size;
  final bool isValid;
  final String? errorMessage;

  String get formattedSize {
    final units = [
      LocaleKeys.workspaceImport_fileSize_units_bytes.tr(),
      LocaleKeys.workspaceImport_fileSize_units_kilobytes.tr(),
      LocaleKeys.workspaceImport_fileSize_units_megabytes.tr(),
      LocaleKeys.workspaceImport_fileSize_units_gigabytes.tr(),
    ];
    var size = this.size.toDouble();
    var unitIndex = 0;

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
  }

  bool get isZipFile => name.toLowerCase().endsWith('.zip');

  ImportFileData copyWith({
    File? file,
    String? name,
    int? size,
    bool? isValid,
    String? errorMessage,
  }) {
    return ImportFileData(
      file: file ?? this.file,
      name: name ?? this.name,
      size: size ?? this.size,
      isValid: isValid ?? this.isValid,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
