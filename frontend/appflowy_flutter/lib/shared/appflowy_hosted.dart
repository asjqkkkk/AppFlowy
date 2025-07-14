import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:flutter/foundation.dart';

Future<bool> isOfficialHosted() async {
  final result = await UserEventGetCloudConfig().send();
  return result.fold(
    (cloudSetting) {
      if (kDebugMode) {
        return true;
      }
      final whiteList = [
        "https://beta.appflowy.cloud",
        "https://test.appflowy.cloud",
      ];

      return whiteList.contains(cloudSetting.serverUrl);
    },
    (err) {
      return false;
    },
  );
}
