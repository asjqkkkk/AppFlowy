import 'dart:async';

import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/startup/tasks/rust_sdk.dart';
import 'package:appflowy/workspace/application/settings/prelude.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/protobuf/flowy-error/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:fixnum/fixnum.dart';

import '../models/user_data_location.dart';
import 'settings_repository.dart';

class RustSettingsRepositoryImpl implements SettingsRepository {
  const RustSettingsRepositoryImpl();

  @override
  Future<FlowyResult<void, FlowyError>> updateUserSettings({
    required Int64 userId,
    bool? startWeekOnMonday,
    int? dateFormat,
    int? timeFormat,
    String? language,
  }) {
    final payload = UpdateUserProfilePayloadPB()..id = userId;

    if (startWeekOnMonday != null) {
      payload.startWeekOn = startWeekOnMonday ? 1 : 0;
    }
    if (dateFormat != null) {
      payload.dateFormat = dateFormat;
    }
    if (timeFormat != null) {
      payload.timeFormat = timeFormat;
    }
    if (language != null) {
      payload.language = language;
    }

    return UserEventUpdateUserProfile(payload).send();
  }

  @override
  Future<FlowyResult<UserDataLocation, FlowyError>>
      getUserDataLocation() async {
    final defaultDirectory = (await appFlowyApplicationDataDirectory()).path;
    final result = await UserEventGetUserSetting().send();

    return result.map(
      (settings) {
        final userDirectory = settings.userFolder;
        return UserDataLocation(
          path: userDirectory,
          isCustom: !userDirectory.contains(defaultDirectory),
        );
      },
    );
  }

  @override
  Future<FlowyResult<UserDataLocation, FlowyError>>
      resetUserDataLocation() async {
    final directory = await appFlowyApplicationDataDirectory();
    await getIt<ApplicationDataStorage>().setPath(directory.path);

    return FlowyResult.success(
      UserDataLocation(
        path: directory.path,
        isCustom: false,
      ),
    );
  }

  @override
  Future<FlowyResult<UserDataLocation, FlowyError>> setCustomLocation(
    String path,
  ) async {
    final defaultDirectory = (await appFlowyApplicationDataDirectory()).path;
    await getIt<ApplicationDataStorage>().setCustomPath(path);

    return FlowyResult.success(
      UserDataLocation(
        path: path,
        isCustom: path.contains(defaultDirectory),
      ),
    );
  }
}
