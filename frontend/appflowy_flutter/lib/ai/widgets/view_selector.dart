import 'package:appflowy/features/workspace/logic/workspace_bloc.dart';
import 'package:appflowy/workspace/application/menu/sidebar_sections_bloc.dart';
import 'package:appflowy/workspace/application/sidebar/space/space_bloc.dart';
import 'package:appflowy/workspace/application/user/prelude.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../service/view_selector_cubit.dart';

class ViewSelector extends StatefulWidget {
  const ViewSelector({
    super.key,
    required this.viewSelectorCubit,
    required this.child,
  });

  final ViewSelectorCubit viewSelectorCubit;
  final Widget child;

  @override
  State<ViewSelector> createState() => ViewSelectorWidgetState();
}

class ViewSelectorWidgetState extends State<ViewSelector> {
  late final SidebarSectionsBloc sidebarSectionsBloc;
  late SpaceBloc spaceBloc;

  @override
  void initState() {
    super.initState();

    final userWorkspaceBloc = context.read<UserWorkspaceBloc>();
    final userProfile = userWorkspaceBloc.state.userProfile;
    final workspaceId =
        userWorkspaceBloc.state.currentWorkspace?.workspaceId ?? '';

    sidebarSectionsBloc = SidebarSectionsBloc()
      ..add(SidebarSectionsEvent.initial(userProfile, workspaceId));
    spaceBloc = SpaceBloc(
      userProfile: userProfile,
      workspaceId: workspaceId,
    )..add(SpaceEvent.initial(openFirstPage: false));
  }

  @override
  void dispose() {
    sidebarSectionsBloc.close();
    spaceBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<UserWorkspaceBloc, UserWorkspaceState>(
      listenWhen: (previous, current) {
        return previous.currentWorkspace?.workspaceId !=
            current.currentWorkspace?.workspaceId;
      },
      listener: (context, state) {
        setState(() {
          spaceBloc.close();
          final userProfile = state.userProfile;
          final workspaceId = state.currentWorkspace?.workspaceId ?? '';
          spaceBloc = SpaceBloc(
            userProfile: userProfile,
            workspaceId: workspaceId,
          )..add(SpaceEvent.initial(openFirstPage: false));
        });
      },
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(
            value: sidebarSectionsBloc,
          ),
          BlocProvider.value(
            value: spaceBloc,
          ),
          BlocProvider.value(
            value: widget.viewSelectorCubit,
          ),
        ],
        child: widget.child,
      ),
    );
  }

  void refreshViews({bool showCurrentSpaceOnly = false}) {
    final List<ViewPB> views;
    final String? initialOpenViewId;

    if (_isAnonMode) {
      views = sidebarSectionsBloc.state.section.publicViews;
      initialOpenViewId = null;
    } else {
      final currentSpace = spaceBloc.state.currentSpace;
      views = showCurrentSpaceOnly && currentSpace != null
          ? [currentSpace]
          : spaceBloc.state.spaces;
      initialOpenViewId = spaceBloc.state.currentSpace?.id;
    }

    widget.viewSelectorCubit.refreshSources(
      views,
      initialOpenViewId,
    );
  }

  bool get _isAnonMode {
    final containsSpace = sidebarSectionsBloc.state.containsSpace;
    final isSpacesEmpty = spaceBloc.state.spaces.isEmpty;
    final isCollabWorkspaceOn =
        context.read<UserWorkspaceBloc>().state.isCollabWorkspaceOn;

    return !containsSpace || isSpacesEmpty || !isCollabWorkspaceOn;
  }
}
