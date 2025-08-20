import 'package:appflowy/features/profile_setting/data/profile.dart';
import 'package:flutter/material.dart';

typedef ProfileBuilder = Widget Function(
  BuildContext context,
  Profile profile,
);

class ProfileListeners {
  static final Map<String, Set<ValueChanged<Profile>>> _listeners = {};

  static void _addListener(String userId, ValueChanged<Profile> listener) {
    final listenerSet = _listeners[userId] ?? {};
    listenerSet.add(listener);
    _listeners[userId] = listenerSet;
  }

  static void _removeListener(String userId, ValueChanged<Profile> listener) {
    final listenerSet = _listeners[userId] ?? {};
    listenerSet.remove(listener);
    _listeners[userId] = listenerSet;
  }

  static void notify(String userId, Profile profile) {
    final set = Set.of(_listeners[userId] ?? {});
    for (final listener in set) {
      listener.call(profile);
    }
  }
}

class ProfileListenerWidget extends StatefulWidget {
  const ProfileListenerWidget({
    super.key,
    required this.userId,
    required this.builder,
  });

  final String userId;
  final ProfileBuilder builder;

  @override
  State<ProfileListenerWidget> createState() => _ProfileListenerWidgetState();
}

class _ProfileListenerWidgetState extends State<ProfileListenerWidget> {
  @override
  void initState() {
    ProfileListeners._addListener(widget.userId, onProfileListener);
    super.initState();
  }

  @override
  void dispose() {
    ProfileListeners._removeListener(widget.userId, onProfileListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }

  void onProfileListener(Profile profile) {}
}
