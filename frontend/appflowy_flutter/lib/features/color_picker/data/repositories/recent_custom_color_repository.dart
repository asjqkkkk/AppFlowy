import '../models/af_color.dart';

abstract class RecentCustomColorRepository {
  Future<List<AFColor>> getRecentColors();

  Future<List<AFColor>> getCustomColors();

  Future<void> saveRecentColors(List<AFColor> colors);

  Future<void> saveCustomColors(List<AFColor> colors);
}
