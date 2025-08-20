import 'package:appflowy/util/string_extension.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';

class HomeScreenWidgetItem {
  HomeScreenWidgetItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.layout,
    this.imageUrl = '',
    this.iconType = 0,
  });

  factory HomeScreenWidgetItem.fromViewPB(ViewPB view) {
    return HomeScreenWidgetItem(
      id: view.id,
      title: view.name.orDefault('Untitled'),
      icon: view.icon.value,
      iconType: view.icon.ty.value,
      layout: view.layout,
    );
  }

  factory HomeScreenWidgetItem.fromApiJson(Map<String, dynamic> json) {
    try {
      String iconValue = '';
      int iconType = 0; // Default to emoji

      final iconData = json['icon'];
      if (iconData is Map<String, dynamic>) {
        // Extract icon type and value from the data
        iconType = iconData['ty'] as int? ?? 0;
        iconValue = iconData['value']?.toString() ?? '';
      }

      final name = json['name']?.toString() ?? '';
      final layout = ViewLayoutPB.valueOf(json['layout'] as int? ?? 0) ??
          ViewLayoutPB.Document;

      return HomeScreenWidgetItem(
        id: json['view_id']?.toString() ?? '',
        title: name.orDefault('Untitled'),
        icon: iconValue.orDefault(' '),
        layout: layout,
        iconType: iconType,
      );
    } catch (e) {
      Log.error('Failed to parse HomeScreenWidgetItem from API JSON: $e');
      return HomeScreenWidgetItem(
        id: '',
        icon: ' ',
        title: '',
        layout: ViewLayoutPB.Document,
      );
    }
  }

  static List<HomeScreenWidgetItem> fromApiResponse(
    Map<String, dynamic> jsonData, {
    int limit = 10,
  }) {
    try {
      final items = <HomeScreenWidgetItem>[];

      if (jsonData['data'] is Map<String, dynamic> &&
          jsonData['data']['views'] is List) {
        final views = jsonData['data']['views'] as List;
        for (final item in views.take(limit)) {
          if (item is Map<String, dynamic>) {
            items.add(HomeScreenWidgetItem.fromApiJson(item));
          }
        }
      }

      return items;
    } catch (e) {
      Log.error('Failed to parse HomeScreenWidgetItems from API response: $e');
      return [];
    }
  }

  final String id;
  final String title;
  final String icon;
  final ViewLayoutPB layout;
  final int iconType; // 0: Emoji, 1: Icon (SVG), 2: URL (network image)

  String imageUrl;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'icon': icon,
        'layout': layout.value,
        'imageUrl': imageUrl,
        'iconType': iconType,
      };
}
