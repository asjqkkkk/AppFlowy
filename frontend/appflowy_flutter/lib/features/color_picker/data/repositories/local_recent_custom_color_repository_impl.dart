import 'dart:convert';

import 'package:appflowy/core/config/kv.dart';
import 'package:appflowy/features/color_picker/data/models/af_color.dart';
import 'package:appflowy_backend/log.dart';

import 'recent_custom_color_repository.dart';

final class LocalRecentCustomColorRepositoryImpl
    implements RecentCustomColorRepository {
  LocalRecentCustomColorRepositoryImpl({
    required this.kv,
    required this.key,
    required this.innerKey,
  });

  final KeyValueStorage kv;
  final String key;
  final String innerKey;

  String get _recentColorsKey => "${key}_recent_colors";
  String get _customColorsKey => "${key}_custom_colors";

  @override
  Future<List<AFColor>> getRecentColors() {
    return _loadColors(_recentColorsKey);
  }

  @override
  Future<List<AFColor>> getCustomColors() {
    return _loadColors(_customColorsKey);
  }

  @override
  Future<void> saveRecentColors(List<AFColor> colors) {
    return _saveColors(_recentColorsKey, colors);
  }

  @override
  Future<void> saveCustomColors(List<AFColor> colors) {
    return _saveColors(_customColorsKey, colors);
  }

  Future<List<AFColor>> _loadColors(String key) async {
    final serializedColorMap = await kv.get(key);
    if (serializedColorMap == null) {
      return [];
    }

    try {
      final allColors = json.decode(serializedColorMap) as Map<String, dynamic>;
      final colorList = allColors[innerKey];

      if (colorList is! List) {
        return [];
      }

      return colorList
          .whereType<String>()
          .map(AFColor.fromValue)
          .toSet()
          .toList();
    } catch (e) {
      Log.error('Failed to load colors: $e');
      return [];
    }
  }

  Future<void> _saveColors(String key, List<AFColor> colors) async {
    try {
      final serializedColorMap = await kv.get(key) ?? '{}';

      final Map<String, dynamic> allColors = json.decode(serializedColorMap);
      allColors[innerKey] = colors.map((e) => e.value).toList();

      await kv.set(key, json.encode(allColors));
    } catch (e) {
      Log.error('Failed to save colors: $e');
    }
  }
}
