import 'package:appflowy/features/shared_section/presentation/m_shared_section.dart';
import 'package:appflowy/features/workspace/logic/workspace_bloc.dart';
import 'package:appflowy/mobile/application/mobile_router.dart';
import 'package:appflowy/mobile/presentation/home/favorite_folder/favorite_space.dart';
import 'package:appflowy/mobile/presentation/home/home_space/home_space.dart';
import 'package:appflowy/mobile/presentation/home/recent_folder/recent_space.dart';
import 'package:appflowy/mobile/presentation/home/tab/_tab_bar.dart';
import 'package:appflowy/mobile/presentation/home/tab/space_order_bloc.dart';
import 'package:appflowy/mobile/presentation/presentation.dart';
import 'package:appflowy/mobile/presentation/setting/workspace/invite_members_screen.dart';
import 'package:appflowy/shared/icon_emoji_picker/tab.dart';
import 'package:appflowy/workspace/application/menu/sidebar_sections_bloc.dart';
import 'package:appflowy/workspace/application/sidebar/folder/folder_bloc.dart';
import 'package:appflowy/workspace/application/sidebar/space/space_bloc.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart'
    hide AFRolePB;
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'ai_bubble_button.dart';

final ValueNotifier<int> mobileCreateNewAIChatNotifier = ValueNotifier(0);

class MobileHomePageTab extends StatefulWidget {
  const MobileHomePageTab({
    super.key,
    required this.userProfile,
  });

  final UserProfilePB userProfile;

  @override
  State<MobileHomePageTab> createState() => _MobileHomePageTabState();
}

class _MobileHomePageTabState extends State<MobileHomePageTab>
    with SingleTickerProviderStateMixin {
  TabController? tabController;

  @override
  void initState() {
    super.initState();

    mobileCreateNewPageNotifier.addListener(_createNewDocument);
    mobileCreateNewAIChatNotifier.addListener(_createNewAIChat);
    mobileLeaveWorkspaceNotifier.addListener(_leaveWorkspace);
  }

  @override
  void dispose() {
    tabController?.removeListener(_onTabChange);
    tabController?.dispose();

    mobileCreateNewPageNotifier.removeListener(_createNewDocument);
    mobileCreateNewAIChatNotifier.removeListener(_createNewAIChat);
    mobileLeaveWorkspaceNotifier.removeListener(_leaveWorkspace);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Provider.value(
      value: widget.userProfile,
      child: MultiBlocListener(
        listeners: [
          BlocListener<SpaceBloc, SpaceState>(
            listenWhen: (p, c) =>
                p.lastCreatedPage?.id != c.lastCreatedPage?.id,
            listener: (context, state) {
              final lastCreatedPage = state.lastCreatedPage;
              if (lastCreatedPage != null) {
                context.pushView(
                  lastCreatedPage,
                  tabs: [
                    PickerTabType.emoji,
                    PickerTabType.icon,
                    PickerTabType.custom,
                  ].map((e) => e.name).toList(),
                );
              }
            },
          ),
          BlocListener<SidebarSectionsBloc, SidebarSectionsState>(
            listenWhen: (p, c) =>
                p.lastCreatedRootView?.id != c.lastCreatedRootView?.id,
            listener: (context, state) {
              final lastCreatedPage = state.lastCreatedRootView;
              if (lastCreatedPage != null) {
                context.pushView(
                  lastCreatedPage,
                  tabs: [
                    PickerTabType.emoji,
                    PickerTabType.icon,
                    PickerTabType.custom,
                  ].map((e) => e.name).toList(),
                );
              }
            },
          ),
        ],
        child: BlocBuilder<SpaceOrderBloc, SpaceOrderState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const SizedBox.shrink();
            }

            final workspace =
                context.read<UserWorkspaceBloc>().state.currentWorkspace;
            final isLocalWorkspace =
                workspace?.workspaceType == WorkspaceTypePB.LocalW;
            final isGuest = workspace?.role == AFRolePB.Guest;

            List<MobileSpaceTabType> tabs = isGuest
                ? [
                    MobileSpaceTabType.shared,
                    MobileSpaceTabType.recent,
                    MobileSpaceTabType.favorites,
                  ]
                : state.tabsOrder;

            if (isLocalWorkspace) {
              tabs = tabs
                  .where((tab) => tab != MobileSpaceTabType.shared)
                  .toList();
            }

            _initTabController(state, tabs);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MobileSpaceTabBar(
                  tabController: tabController!,
                  tabs: tabs,
                  onReorder: (from, to) {
                    context.read<SpaceOrderBloc>().add(
                          SpaceOrderEvent.reorder(from, to),
                        );
                  },
                ),
                const HSpace(12.0),
                Expanded(
                  child: TabBarView(
                    controller: tabController,
                    children: _buildTabs(state, tabs),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _initTabController(
    SpaceOrderState state,
    List<MobileSpaceTabType> tabs,
  ) {
    if (tabController != null) {
      return;
    }
    tabController = TabController(
      length: tabs.length,
      vsync: this,
      initialIndex: tabs.indexOf(state.defaultTab).clamp(0, tabs.length - 1),
    );
    tabController?.addListener(_onTabChange);
  }

  void _onTabChange() {
    if (tabController == null) {
      return;
    }
    context
        .read<SpaceOrderBloc>()
        .add(SpaceOrderEvent.open(tabController!.index));
  }

  List<Widget> _buildTabs(
    SpaceOrderState state,
    List<MobileSpaceTabType> tabs,
  ) {
    return tabs.map((tab) {
      switch (tab) {
        case MobileSpaceTabType.recent:
          return const MobileRecentSpace();
        case MobileSpaceTabType.spaces:
          final showAIFloatingButton =
              widget.userProfile.workspaceType == WorkspaceTypePB.ServerW;
          return Stack(
            children: [
              MobileHomeSpace(userProfile: widget.userProfile),
              if (showAIFloatingButton)
                Positioned(
                  right: 20,
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  child: FloatingAIEntryV2(),
                ),
            ],
          );
        case MobileSpaceTabType.favorites:
          return MobileFavoriteSpace(userProfile: widget.userProfile);
        case MobileSpaceTabType.shared:
          final workspace =
              context.read<UserWorkspaceBloc>().state.currentWorkspace;
          if (workspace == null ||
              workspace.workspaceType == WorkspaceTypePB.LocalW) {
            return const SizedBox.shrink();
          }
          return MSharedSection(
            workspaceId: workspace.workspaceId,
          );
      }
    }).toList();
  }

  // quick create new page when clicking the add button in navigation bar
  void _createNewDocument() => _createNewPage(ViewLayoutPB.Document);

  void _createNewAIChat() => _createNewPage(ViewLayoutPB.Chat);

  void _createNewPage(ViewLayoutPB layout) {
    final role = context.read<UserWorkspaceBloc>().state.currentWorkspace?.role;
    if (role == AFRolePB.Guest) {
      showToastNotification(
        // todo: i18n
        message: 'You don\'t have permission to create a page as a guest',
        type: ToastificationType.error,
      );
      return;
    }

    if (context.read<SpaceBloc>().state.spaces.isNotEmpty) {
      context.read<SpaceBloc>().add(
            SpaceEvent.createPage(
              name: '',
              layout: layout,
              openAfterCreate: true,
            ),
          );
    } else if (layout == ViewLayoutPB.Document) {
      // only support create document in section
      context.read<SidebarSectionsBloc>().add(
            SidebarSectionsEvent.createRootViewInSection(
              name: '',
              index: 0,
              viewSection: FolderSpaceType.public.toViewSectionPB,
            ),
          );
    }
  }

  void _leaveWorkspace() {
    final workspaceId =
        context.read<UserWorkspaceBloc>().state.currentWorkspace?.workspaceId;
    if (workspaceId == null) {
      return Log.error('Workspace ID is null');
    }
    context
        .read<UserWorkspaceBloc>()
        .add(UserWorkspaceEvent.leaveWorkspace(workspaceId: workspaceId));
  }
}
