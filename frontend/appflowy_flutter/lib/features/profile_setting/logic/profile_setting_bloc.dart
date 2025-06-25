import 'package:appflowy/features/profile_setting/data/repository/mock_profile_setting.repository.dart';
import 'package:appflowy/features/profile_setting/data/repository/profile_setting_repository.dart';
import 'package:appflowy_backend/protobuf/flowy-user/user_profile.pb.dart';
import 'package:bloc/bloc.dart';

import 'profile_setting_event.dart';
import 'profile_setting_state.dart';

class ProfileSettingBloc
    extends Bloc<ProfileSettingEvent, ProfileSettingState> {
  ProfileSettingBloc({
    ProfileSettingRepository? repository,
    required this.userProfile,
    this.workspace,
  })  : repository = repository ?? MockProfileSettingRepository(),
        super(ProfileSettingState.empty()) {
    on<ProfileSettingInitialEvent>(_onInitial);
    on<ProfileSettingUpdateNameEvent>(_onUpdateName);
    on<ProfileSettingUpdateAboutMeEvent>(_onUpdateAboutMe);
    on<ProfileSettingUpdateAvatarEvent>(_onUpdateAvatarUrl);
    on<ProfileSettingUpdateBannerEvent>(_onUpdateBanner);
    on<ProfileSettingSelectBannerEvent>(_onSelectBanner);
  }

  final ProfileSettingRepository repository;
  final UserProfilePB userProfile;
  final UserWorkspacePB? workspace;

  Future<void> _onInitial(
    ProfileSettingInitialEvent event,
    Emitter<ProfileSettingState> emit,
  ) async {
    final result = await repository.getProfile(userProfile.id.toString());
    result.fold((v) {
      if (isClosed) return;
      emit(state.copyWith(profile: v, status: ProfileSettingStatus.idle));
    }, (e) {
      if (isClosed) return;
      emit(state.copyWith(status: ProfileSettingStatus.failed));
    });
  }

  Future<void> _onUpdateName(
    ProfileSettingUpdateNameEvent event,
    Emitter<ProfileSettingState> emit,
  ) async {
    emit(
      state.copyWith(
        profile: state.profile.copyWith(name: event.name),
        hasChanged: true,
      ),
    );
  }

  Future<void> _onUpdateAboutMe(
    ProfileSettingUpdateAboutMeEvent event,
    Emitter<ProfileSettingState> emit,
  ) async {
    emit(
      state.copyWith(
        profile: state.profile.copyWith(aboutMe: event.aboutMe),
        hasChanged: true,
      ),
    );
  }

  Future<void> _onUpdateAvatarUrl(
    ProfileSettingUpdateAvatarEvent event,
    Emitter<ProfileSettingState> emit,
  ) async {
    emit(
      state.copyWith(
        profile: state.profile.copyWith(avatarUrl: event.avatarUrl),
        hasChanged: true,
      ),
    );
  }

  Future<void> _onUpdateBanner(
    ProfileSettingUpdateBannerEvent event,
    Emitter<ProfileSettingState> emit,
  ) async {
    emit(
      state.copyWith(
        profile: state.profile.copyWith(banner: event.banner),
        hasChanged: true,
      ),
    );
  }

  Future<void> _onSelectBanner(
    ProfileSettingSelectBannerEvent event,
    Emitter<ProfileSettingState> emit,
  ) async {
    emit(
      state.copyWith(selectedBanner: event.banner, hasChanged: true),
    );
  }
}
