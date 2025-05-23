import 'package:easy_localization/easy_localization.dart';

import '../startup.dart';

class InitLocalizationTask extends LaunchTask {
  const InitLocalizationTask();

  @override
  Future<void> initialize(LaunchContext context) async {
    await super.initialize(context);

    await EasyLocalization.ensureInitialized();
    EasyLocalization.logger.enableBuildModes = [];
  }
}
