import 'dart:async';

import 'package:appflowy/core/notification/folder_notification.dart';
import 'package:appflowy/features/page_access_level/data/repositories/page_access_level_repository.dart';
import 'package:appflowy/features/page_access_level/data/repositories/rust_page_access_level_repository_impl.dart';
import 'package:appflowy/features/page_access_level/logic/page_access_level_event.dart';
import 'package:appflowy/features/page_access_level/logic/page_access_level_state.dart';
import 'package:appflowy/features/share_tab/data/models/models.dart';
import 'package:appflowy/features/share_tab/data/repositories/rust_share_with_user_repository_impl.dart';
import 'package:appflowy/features/share_tab/data/repositories/share_with_user_repository.dart';
import 'package:appflowy/features/util/extensions.dart';
import 'package:appflowy/shared/feature_flags.dart';
import 'package:appflowy/workspace/application/view/view_listener.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:protobuf/protobuf.dart';

export 'page_access_level_event.dart';
export 'page_access_level_state.dart';

class PageAccessLevelBloc
    extends Bloc<PageAccessLevelEvent, PageAccessLevelState> {
  PageAccessLevelBloc({
    required this.view,
    this.ignorePageAccessLevel = false,
    PageAccessLevelRepository? pageAccessRepository,
    ShareWithUserRepository? shareRepository,
  })  : pageAccessRepository =
            pageAccessRepository ?? RustPageAccessLevelRepositoryImpl(),
        shareRepository = shareRepository ?? RustShareWithUserRepositoryImpl(),
        _viewListener = ViewListener(viewId: view.id),
        super(PageAccessLevelState.initial(view)) {
    on<PageAccessLevelInitialEvent>(_onInitial);
    on<PageAccessLevelLockEvent>(_onLock);
    on<PageAccessLevelUnlockEvent>(_onUnlock);
    on<PageAccessLevelUpdateLockStatusEvent>(_onUpdateLockStatus);
    on<PageAccessLevelUpdateSectionTypeEvent>(_onUpdateSectionType);
    on<PageAccessLevelRefreshAccessLevelEvent>(_onRefreshAccessLevel);
  }

  final ViewPB view;

  // The repository to manage view lock status.
  // If you need to test this bloc, you can add your own repository implementation.
  final PageAccessLevelRepository pageAccessRepository;

  /// The repository to manage share page.
  final ShareWithUserRepository shareRepository;

  // Used to listen for view updates.
  late final ViewListener _viewListener;

  // Used to listen for folder notification.
  late final FolderNotificationListener _folderNotificationListener;

  // should ignore the page access level
  // in the row details page, we don't need to check the page access level
  final bool ignorePageAccessLevel;

  // This value is used to compare with the latest shared users to get the diff.
  SharedUsers _sharedUsers = [];

  @override
  Future<void> close() async {
    await _viewListener.stop();
    await _folderNotificationListener.stop();
    return super.close();
  }

  Future<void> _onInitial(
    PageAccessLevelInitialEvent event,
    Emitter<PageAccessLevelState> emit,
  ) async {
    _initListeners();

    // section type
    final sectionTypeResult =
        await pageAccessRepository.getSectionType(view.id);
    final sectionType = sectionTypeResult.fold(
      (sectionType) => sectionType,
      (_) => SharedSectionType.public,
    );

    if (!FeatureFlag.sharedSection.isOn || ignorePageAccessLevel) {
      emit(
        state.copyWith(
          view: view,
          isLocked: view.isLocked,
          isLoadingLockStatus: false,
          accessLevel: ShareAccessLevel.fullAccess,
          sectionType: sectionType,
          isInitializing: false,
        ),
      );
      return;
    }

    final userProfileResult =
        await pageAccessRepository.getCurrentUserProfile();
    final email = userProfileResult.fold(
      (userProfile) => userProfile.email,
      (_) => '',
    );

    final result = await pageAccessRepository.getView(view.id);

    final sharedUsers =
        await shareRepository.getSharedUsersInPage(pageId: view.id);
    _sharedUsers = sharedUsers.fold(
      (sharedUsers) => sharedUsers,
      (_) => [],
    );

    final accessLevel =
        await pageAccessRepository.getAccessLevel(view.id, email);
    final latestView = result.fold(
      (view) => view,
      (_) => view,
    );
    emit(
      state.copyWith(
        view: latestView,
        isLocked: latestView.isLocked,
        isLoadingLockStatus: false,
        accessLevel: accessLevel.fold(
          (accessLevel) => accessLevel,
          (_) => ShareAccessLevel.readOnly,
        ),
        sectionType: sectionType,
        isInitializing: false,
        email: email,
      ),
    );
  }

  Future<void> _onLock(
    PageAccessLevelLockEvent event,
    Emitter<PageAccessLevelState> emit,
  ) async {
    final result = await pageAccessRepository.lockView(view.id);
    final isLocked = result.fold(
      (_) => true,
      (_) => false,
    );
    add(
      PageAccessLevelEvent.updateLockStatus(
        isLocked,
      ),
    );
  }

  Future<void> _onUnlock(
    PageAccessLevelUnlockEvent event,
    Emitter<PageAccessLevelState> emit,
  ) async {
    final result = await pageAccessRepository.unlockView(view.id);
    final isLocked = result.fold(
      (_) => false,
      (_) => true,
    );
    add(
      PageAccessLevelEvent.updateLockStatus(
        isLocked,
        lockCounter: state.lockCounter + 1,
      ),
    );
  }

  void _onUpdateLockStatus(
    PageAccessLevelUpdateLockStatusEvent event,
    Emitter<PageAccessLevelState> emit,
  ) {
    state.view.freeze();
    final updatedView = state.view.rebuild(
      (update) => update.isLocked = event.isLocked,
    );
    emit(
      state.copyWith(
        view: updatedView,
        isLocked: event.isLocked,
        lockCounter: event.lockCounter ?? state.lockCounter,
      ),
    );
  }

  void _onUpdateSectionType(
    PageAccessLevelUpdateSectionTypeEvent event,
    Emitter<PageAccessLevelState> emit,
  ) {
    emit(
      state.copyWith(
        sectionType: event.sectionType,
      ),
    );
  }

  Future<void> _onRefreshAccessLevel(
    PageAccessLevelRefreshAccessLevelEvent event,
    Emitter<PageAccessLevelState> emit,
  ) async {
    final sectionTypeResult =
        await pageAccessRepository.getSectionType(view.id);
    final sectionType = sectionTypeResult.fold(
      (sectionType) => sectionType,
      (_) => SharedSectionType.public,
    );
    final accessLevel =
        await pageAccessRepository.getAccessLevel(view.id, state.email);
    emit(
      state.copyWith(
        accessLevel: accessLevel.fold(
          (accessLevel) => accessLevel,
          (_) => ShareAccessLevel.readOnly,
        ),
        sectionType: sectionType,
      ),
    );
  }

  void _initListeners() {
    // lock status
    _viewListener.start(
      onViewUpdated: (view) async {
        add(PageAccessLevelEvent.updateLockStatus(view.isLocked));
      },
    );

    _folderNotificationListener = FolderNotificationListener(
      objectId: view.id,
      handler: (notification, result) {
        if (notification == FolderNotification.DidUpdateSharedUsers) {
          result.fold(
            (payload) {
              final sharedUsers =
                  RepeatedSharedUserPB.fromBuffer(payload).sharedUsers;
              final isSame = setEquals(
                _sharedUsers.toSet(),
                sharedUsers.toSet(),
              );

              _sharedUsers = sharedUsers;

              if (isSame) {
                return;
              }

              add(PageAccessLevelEvent.refreshAccessLevel());
            },
            (error) => null,
          );
        }
      },
    );
  }
}
