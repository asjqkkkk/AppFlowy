import 'package:appflowy/features/share_tab/data/models/share_role.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pbenum.dart';
import 'package:appflowy_backend/protobuf/flowy-user/user_profile.pb.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'banner.dart';

class Profile extends Equatable {
  Profile.empty()
      : id = '',
        email = '',
        name = '',
        avatarUrl = '',
        aboutMe = '',
        role = ShareRole.member,
        banner = EmptyBanner.instance,
        customBanner = null;

  const Profile({
    required this.id,
    required this.email,
    required this.name,
    required this.avatarUrl,
    required this.aboutMe,
    required this.banner,
    required this.role,
    this.customBanner,
  });

  final String id;
  final String email;
  final String name;
  final String avatarUrl;
  final String aboutMe;
  final ShareRole role;
  final BannerData banner;
  final NetworkImageBanner? customBanner;

  Profile copyWith({
    String? id,
    String? email,
    String? name,
    String? avatarUrl,
    String? aboutMe,
    ShareRole? role,
    BannerData? banner,
    ValueGetter<NetworkImageBanner?>? customBanner,
  }) {
    return Profile(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      aboutMe: aboutMe ?? this.aboutMe,
      role: role ?? this.role,
      banner: banner ?? this.banner,
      customBanner: customBanner != null ? customBanner() : this.customBanner,
    );
  }

  static ShareRole fromProtoToShareRole(MentionablePersonTypePB role) {
    switch (role) {
      case MentionablePersonTypePB.WorkspaceMember:
        return ShareRole.member;
      case MentionablePersonTypePB.WorkspaceGuest:
        return ShareRole.guest;
      case MentionablePersonTypePB.Contact:
        throw ArgumentError('Unknown role: $role');
      default:
        throw ArgumentError('Unknown role: $role');
    }
  }

  @override
  List<Object?> get props => [
        id,
        email,
        name,
        avatarUrl,
        aboutMe,
        role,
        banner,
        customBanner,
      ];

  UserProfilePB toUserProfilePB(UserProfilePB v) {
    return UserProfilePB(
      id: v.id,
      name: name,
      email: email,
      iconUrl: avatarUrl,
      token: v.token,
      userAuthType: v.userAuthType,
      workspaceType: v.workspaceType,
    );
  }
}
