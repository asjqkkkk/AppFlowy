import 'package:appflowy/features/home_screen_widget/data/models/home_screen_widget_item.dart';
import 'package:appflowy/features/home_screen_widget/data/models/home_screen_workspace_info.dart';

class HomeScreenWidgetData {
  const HomeScreenWidgetData({
    required this.isUserLogin,
    required this.currentWorkspaceId,
    required this.workspaces,
    required this.favorites,
    required this.recent,
    required this.lastSync,
  });

  factory HomeScreenWidgetData.notLoggedIn() {
    return HomeScreenWidgetData(
      isUserLogin: false,
      currentWorkspaceId: null,
      workspaces: const [],
      favorites: const [],
      recent: const [],
      lastSync: DateTime.now(),
    );
  }

  factory HomeScreenWidgetData.loggedIn({
    required String currentWorkspaceId,
    required List<HomeScreenWorkspaceInfo> workspaces,
    required List<HomeScreenWidgetItem> favorites,
    required List<HomeScreenWidgetItem> recent,
  }) {
    return HomeScreenWidgetData(
      isUserLogin: true,
      currentWorkspaceId: currentWorkspaceId,
      workspaces: workspaces,
      favorites: favorites,
      recent: recent,
      lastSync: DateTime.now(),
    );
  }

  final bool isUserLogin;
  final String? currentWorkspaceId;
  final List<HomeScreenWorkspaceInfo> workspaces;
  final List<HomeScreenWidgetItem> favorites;
  final List<HomeScreenWidgetItem> recent;
  final DateTime lastSync;

  Map<String, dynamic> toJson() => {
        'is_user_login': isUserLogin,
        'current_workspace_id': currentWorkspaceId,
        'workspaces':
            workspaces.map((workspace) => workspace.toJson()).toList(),
        'favorites': favorites.map((item) => item.toJson()).toList(),
        'recent': recent.map((item) => item.toJson()).toList(),
        'last_sync': lastSync.toIso8601String(),
      };

  HomeScreenWidgetData copyWith({
    bool? isUserLogin,
    String? currentWorkspaceId,
    List<HomeScreenWorkspaceInfo>? workspaces,
    List<HomeScreenWidgetItem>? favorites,
    List<HomeScreenWidgetItem>? recent,
    DateTime? lastSync,
  }) {
    return HomeScreenWidgetData(
      isUserLogin: isUserLogin ?? this.isUserLogin,
      currentWorkspaceId: currentWorkspaceId ?? this.currentWorkspaceId,
      workspaces: workspaces ?? this.workspaces,
      favorites: favorites ?? this.favorites,
      recent: recent ?? this.recent,
      lastSync: lastSync ?? this.lastSync,
    );
  }

  @override
  String toString() {
    return 'HomeScreenWidgetData('
        'isUserLogin: $isUserLogin, '
        'currentWorkspaceId: $currentWorkspaceId, '
        'workspaces: ${workspaces.length}, '
        'favorites: ${favorites.length}, '
        'recent: ${recent.length}, '
        'lastSync: $lastSync)';
  }
}
