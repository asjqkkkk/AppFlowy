import 'dart:io';

import 'package:appflowy/core/helpers/url_launcher.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:archive/archive_io.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/file_picker/file_picker_service.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> shareLogFiles(
  BuildContext? context, {
  String? customExportPath,
}) async {
  final dir = await getApplicationSupportDirectory();
  final zipEncoder = ZipEncoder();

  final archiveLogFiles = <ArchiveFile>[];

  final logDirectories = dir
      .listSync(recursive: true)
      .where((e) => e is File && p.basename(e.path).startsWith('log.'))
      .map((e) => p.dirname(e.path))
      .toSet();

  for (final logDir in logDirectories) {
    final relativePath = p.relative(logDir, from: dir.path);
    final logFiles = Directory(logDir)
        .listSync()
        .where((e) => e is File && p.basename(e.path).startsWith('log.'))
        .cast<File>();

    for (final logFile in logFiles) {
      final bytes = logFile.readAsBytesSync();
      final archivePath = p.join(relativePath, p.basename(logFile.path));
      archiveLogFiles.add(ArchiveFile(archivePath, bytes.length, bytes));
    }
  }

  if (archiveLogFiles.isEmpty) {
    if (context != null && context.mounted) {
      showToastNotification(
        message: LocaleKeys.noLogFiles.tr(),
        type: ToastificationType.error,
      );
    }
    return;
  }

  final archive = Archive();
  for (final file in archiveLogFiles) {
    archive.addFile(file);
  }

  final zip = zipEncoder.encode(archive);
  if (zip == null) {
    if (context != null && context.mounted) {
      showToastNotification(
        message: LocaleKeys.noLogFiles.tr(),
        type: ToastificationType.error,
      );
    }
    return;
  }

  // create a zipped appflowy logs file
  try {
    final tempDirectory = await getTemporaryDirectory();
    final path = customExportPath ??
        (Platform.isAndroid ? tempDirectory.path : dir.path);
    final zipFileName = 'appflowy_logs.zip';

    if (Platform.isIOS) {
      final zipFile = await File(p.join(path, zipFileName)).writeAsBytes(zip);
      await Share.shareUri(zipFile.uri);
      // delete the zipped appflowy logs file
      await zipFile.delete();
    } else if (Platform.isAndroid) {
      final zipFile = await File(p.join(path, zipFileName)).writeAsBytes(zip);
      await Share.shareXFiles([XFile(zipFile.path)]);
      // delete the zipped appflowy logs file
      await zipFile.delete();
    } else {
      // open the directory
      final downloadPath = await getDownloadsDirectory();
      final result = await getIt<FilePickerService>().saveFile(
        fileName: zipFileName,
        type: FileType.custom,
        allowedExtensions: ['zip'],
        initialDirectory: downloadPath?.path,
      );

      if (context != null && context.mounted) {
        if (result != null) {
          await File(result).writeAsBytes(zip);
          await afLaunchUrlString(result);
          showToastNotification(
            message: 'Exported log files successfully',
          );
        } else {
          showToastNotification(
            message: 'Failed to export log files',
            type: ToastificationType.error,
          );
        }
      }
    }
  } catch (e) {
    if (context != null && context.mounted) {
      showToastNotification(
        message: e.toString(),
        type: ToastificationType.error,
      );
    }
  }
}
