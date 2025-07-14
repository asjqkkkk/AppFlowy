import 'package:appflowy/ai/service/view_selector_cubit.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/bottom_sheet.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/bottom_sheet_buttons.dart';
import 'package:appflowy/plugins/document/application/document_bloc.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy/workspace/presentation/home/menu/view/view_item.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../view_selector.dart';
import 'select_sources_menu.dart';

class PromptInputMobileSelectSourcesButton extends StatefulWidget {
  const PromptInputMobileSelectSourcesButton({
    super.key,
    required this.selectedSourcesNotifier,
    required this.onUpdateSelectedSources,
  });

  final ValueNotifier<List<String>> selectedSourcesNotifier;
  final void Function(List<String>) onUpdateSelectedSources;

  @override
  State<PromptInputMobileSelectSourcesButton> createState() =>
      _PromptInputMobileSelectSourcesButtonState();
}

class _PromptInputMobileSelectSourcesButtonState
    extends State<PromptInputMobileSelectSourcesButton> {
  final key = GlobalKey<ViewSelectorWidgetState>();

  late final cubit = ViewSelectorCubit(
    maxSelectedParentPageCount: 3,
    getIgnoreViewType: (item) {
      if (item.view.isSpace) {
        return IgnoreViewType.none;
      }
      if (item.view.layout != ViewLayoutPB.Document) {
        return IgnoreViewType.hide;
      }
      return IgnoreViewType.none;
    },
  );

  @override
  void initState() {
    super.initState();
    widget.selectedSourcesNotifier.addListener(onSelectedSourcesChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onSelectedSourcesChanged();
    });
  }

  @override
  void dispose() {
    widget.selectedSourcesNotifier.removeListener(onSelectedSourcesChanged);
    cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ViewSelector(
      key: key,
      viewSelectorCubit: cubit,
      child: FlowyButton(
        margin: const EdgeInsetsDirectional.fromSTEB(4, 6, 2, 6),
        expandText: false,
        text: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlowySvg(
              FlowySvgs.ai_page_s,
              color: Theme.of(context).iconTheme.color,
              size: const Size.square(20.0),
            ),
            const HSpace(2.0),
            ValueListenableBuilder(
              valueListenable: widget.selectedSourcesNotifier,
              builder: (context, selectedSourceIds, _) {
                final documentId = context.read<DocumentBloc?>()?.documentId;
                final label = documentId != null &&
                        selectedSourceIds.length == 1 &&
                        selectedSourceIds[0] == documentId
                    ? LocaleKeys.chat_currentPage.tr()
                    : selectedSourceIds.length.toString();
                return FlowyText(
                  label,
                  fontSize: 14,
                  figmaLineHeight: 20,
                  color: Theme.of(context).hintColor,
                );
              },
            ),
            const HSpace(2.0),
            FlowySvg(
              FlowySvgs.ai_source_drop_down_s,
              color: Theme.of(context).hintColor,
              size: const Size.square(10),
            ),
          ],
        ),
        onTap: () async {
          key.currentState?.refreshViews();

          await showDraggableMobileBottomSheet<void>(
            context,
            initialExtent: 0.5,
            stops: [0.0, 0.5, 1.0],
            headerBuilder: (context) => BottomSheetHeaderV2(
              title: LocaleKeys.chat_selectSources.tr(),
              leading: BottomSheetCloseButton(
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            builder: (context) {
              return BlocProvider.value(
                value: cubit,
                child: _MobileSelectSourcesSheetBody(),
              );
            },
          );
          if (context.mounted) {
            widget.onUpdateSelectedSources(cubit.selectedSourceIds);
          }
        },
      ),
    );
  }

  void onSelectedSourcesChanged() {
    cubit
      ..updateSelectedSources(widget.selectedSourcesNotifier.value)
      ..updateSelectedStatus();
  }
}

class _MobileSelectSourcesSheetBody extends StatelessWidget {
  const _MobileSelectSourcesSheetBody();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: PrimaryScrollController.of(context),
      slivers: [
        BlocBuilder<ViewSelectorCubit, ViewSelectorState>(
          builder: (context, state) {
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                childCount: state.selectedSources.length,
                (context, index) {
                  final source = state.selectedSources.elementAt(index);
                  return ViewSelectorTreeItem(
                    key: ValueKey(
                      'selected_select_sources_tree_item_${source.view.id}',
                    ),
                    viewSelectorItem: source,
                    level: 0,
                    isDescendentOfSpace: source.view.isSpace,
                    isSelectedSection: true,
                    onSelected: (item) {
                      context
                          .read<ViewSelectorCubit>()
                          .toggleSelectedStatus(item, true);
                    },
                    height: 40.0,
                  );
                },
              ),
            );
          },
        ),
        BlocBuilder<ViewSelectorCubit, ViewSelectorState>(
          builder: (context, state) {
            if (state.selectedSources.isNotEmpty &&
                state.visibleSources.isNotEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: AFDivider(),
                ),
              );
            }

            return const SliverToBoxAdapter();
          },
        ),
        BlocBuilder<ViewSelectorCubit, ViewSelectorState>(
          builder: (context, state) {
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                childCount: state.visibleSources.length,
                (context, index) {
                  final source = state.visibleSources.elementAt(index);
                  return ViewSelectorTreeItem(
                    key: ValueKey(
                      'visible_select_sources_tree_item_${source.view.id}',
                    ),
                    viewSelectorItem: source,
                    level: 0,
                    isDescendentOfSpace: source.view.isSpace,
                    isSelectedSection: false,
                    onSelected: (item) {
                      context
                          .read<ViewSelectorCubit>()
                          .toggleSelectedStatus(item, false);
                    },
                    height: 40.0,
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
