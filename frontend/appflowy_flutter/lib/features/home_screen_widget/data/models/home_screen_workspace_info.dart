class HomeScreenWorkspaceInfo {
  const HomeScreenWorkspaceInfo({
    required this.id,
    required this.name,
    required this.icon,
    required this.email,
  });

  factory HomeScreenWorkspaceInfo.fromJson(Map<String, dynamic> json) {
    return HomeScreenWorkspaceInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }

  final String id;
  final String name;
  final String icon;
  final String email;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'email': email,
      };
}
