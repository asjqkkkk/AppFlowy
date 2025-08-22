import 'dart:convert';

import 'package:appflowy/features/profile_setting/data/banner.dart';
import 'package:appflowy/features/profile_setting/data/repository/profile_setting_repository.dart';
import 'package:appflowy/features/profile_setting/data/repository/rust_profile_setting_repository.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-user/user_profile.pb.dart';
import 'package:bloc/bloc.dart';

import 'profile_setting_event.dart';
import 'profile_setting_state.dart';

class ProfileSettingBloc
    extends Bloc<ProfileSettingEvent, ProfileSettingState> {
  ProfileSettingBloc({
    ProfileSettingRepository? repository,
    required this.userProfile,
    required this.workspaceId,
  })  : repository = repository ??
            RustProfileSettingRepository(userProfile: userProfile),
        super(ProfileSettingState.empty()) {
    on<ProfileSettingInitialEvent>(_onInitial);
    on<ProfileSettingUpdateNameEvent>(_onUpdateName);
    on<ProfileSettingUpdateAboutMeEvent>(_onUpdateAboutMe);
    on<ProfileSettingUpdateAvatarEvent>(_onUpdateAvatarUrl);
    on<ProfileSettingUploadBannerEvent>(_onUploadBanner);
    on<ProfileSettingSelectBannerEvent>(_onSelectBanner);
  }

  final ProfileSettingRepository repository;
  final UserProfilePB userProfile;
  final String workspaceId;

  Future<void> _onInitial(
    ProfileSettingInitialEvent event,
    Emitter<ProfileSettingState> emit,
  ) async {
    final result = await repository.getProfile(
      userProfile.id.toString(),
    );
    result.fold((v) {
      if (isClosed) return;
      emit(
        state.copyWith(
          profile: v,
          status: ProfileSettingStatus.idle,
          selectedBanner: v.banner,
        ),
      );
    }, (e) {
      if (isClosed) return;
      emit(state.copyWith(status: ProfileSettingStatus.failed));
    });
  }

  Future<void> _onUpdateName(
    ProfileSettingUpdateNameEvent event,
    Emitter<ProfileSettingState> emit,
  ) async {
    final newProfile = state.profile.copyWith(name: event.name);
    emit(state.copyWith(profile: newProfile));
    await repository.updateProfile(newProfile);
  }

  Future<void> _onUpdateAboutMe(
    ProfileSettingUpdateAboutMeEvent event,
    Emitter<ProfileSettingState> emit,
  ) async {
    final newProfile = state.profile.copyWith(aboutMe: event.aboutMe);
    emit(state.copyWith(profile: newProfile));
    await repository.updateProfile(newProfile);
  }

  Future<void> _onUpdateAvatarUrl(
    ProfileSettingUpdateAvatarEvent event,
    Emitter<ProfileSettingState> emit,
  ) async {
    final newProfile = state.profile.copyWith(avatarUrl: event.avatarUrl);
    emit(state.copyWith(profile: newProfile));
    await repository.updateProfile(newProfile);
  }

  Future<void> _onUploadBanner(
    ProfileSettingUploadBannerEvent event,
    Emitter<ProfileSettingState> emit,
  ) async {
    final newBanner = event.banner;
    final newProfile = state.profile.copyWith(
      banner: newBanner ?? defaultBanners.first,
      customBanner: () => newBanner,
    );
    if (newBanner == null) {
      emit(
        state.copyWith(
          profile: newProfile,
          selectedBanner: defaultBanners.first,
        ),
      );
    } else {
      emit(state.copyWith(profile: newProfile, selectedBanner: newBanner));
    }
    await repository.updateProfile(newProfile);
  }

  Future<void> _onSelectBanner(
    ProfileSettingSelectBannerEvent event,
    Emitter<ProfileSettingState> emit,
  ) async {
    final newProfile = state.profile.copyWith(banner: event.banner);
    emit(state.copyWith(profile: newProfile, selectedBanner: event.banner));
    await repository.updateProfile(newProfile);
  }
}

extension HttpHeaderExtension on UserProfilePB {
  Map<String, String> buildRequestHeader() {
    final header = <String, String>{};
    try {
      final decodedToken = jsonDecode(token);
      header['Authorization'] = 'Bearer ${decodedToken['access_token']}';
    } catch (e) {
      Log.error('Unable to decode token: $e');
    }
    return header;
  }
}
