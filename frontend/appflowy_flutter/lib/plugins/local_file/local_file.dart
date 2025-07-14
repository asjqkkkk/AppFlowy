import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/plugins/local_file/presentation/local_file_page.dart';
import 'package:appflowy/startup/plugin/plugin.dart';
import 'package:appflowy/workspace/presentation/home/home_stack.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:flutter/material.dart';

class LocalFilePluginBuilder extends PluginBuilder {
  @override
  Plugin build(dynamic data) {
    if (data is LocalFileData) {
      return LocalFilePlugin(data: data);
    }
    throw FlowyPluginException.invalidData;
  }

  @override
  String get menuName => "Local File";

  @override
  FlowySvgData get icon => FlowySvgs.icon_document_s;

  @override
  PluginType get pluginType => PluginType.localFile;

  @override
  ViewLayoutPB? get layoutType => null;
}

class LocalFilePluginConfig implements PluginConfig {
  @override
  bool get creatable => false;
}

class LocalFileData {
  LocalFileData({
    required this.filePath,
    required this.fileName,
    this.mimeType,
  });

  final String filePath;
  final String fileName;
  final String? mimeType;
}

class LocalFilePlugin extends Plugin {
  LocalFilePlugin({
    required this.data,
  }) : _pluginType = PluginType.localFile;

  final LocalFileData data;
  final PluginType _pluginType;

  @override
  PluginWidgetBuilder get widgetBuilder => LocalFilePluginWidgetBuilder(
        data: data,
      );

  @override
  PluginType get pluginType => _pluginType;

  @override
  PluginId get id => data.filePath;

  @override
  void init() {}
}

class LocalFilePluginWidgetBuilder extends PluginWidgetBuilder
    with NavigationItem {
  LocalFilePluginWidgetBuilder({
    required this.data,
  });

  final LocalFileData data;

  @override
  Widget buildWidget({
    required PluginContext context,
    required bool shrinkWrap,
    Map<String, dynamic>? data,
  }) {
    return LocalFilePage(
      key: ValueKey(this.data.filePath),
      fileData: this.data,
    );
  }

  @override
  List<NavigationItem> get navigationItems => [this];

  @override
  Widget get leftBarItem => const SizedBox.shrink();

  @override
  Widget tabBarItem(String pluginId, [bool shortForm = false]) => leftBarItem;

  @override
  String? get viewName => data.fileName;
}
