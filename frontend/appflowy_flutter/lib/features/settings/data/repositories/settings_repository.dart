import 'package:appflowy_backend/protobuf/flowy-error/protobuf.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:fixnum/fixnum.dart';

import '../models/user_data_location.dart';

abstract class SettingsRepository {
  Future<FlowyResult<void, FlowyError>> updateUserSettings({
    required Int64 userId,
    int? dateFormat,
    int? timeFormat,
    bool? startWeekOnMonday,
    String? language,
  });

  Future<FlowyResult<UserDataLocation, FlowyError>> getUserDataLocation();

  Future<FlowyResult<UserDataLocation, FlowyError>> resetUserDataLocation();

  Future<FlowyResult<UserDataLocation, FlowyError>> setCustomLocation(
    String path,
  );
}
