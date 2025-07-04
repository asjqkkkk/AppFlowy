import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/trash/src/sizes.dart';
import 'package:appflowy/plugins/trash/src/trash_header.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/style_widget/scrolling/styled_list.dart';
import 'package:flowy_infra_ui/style_widget/scrolling/styled_scroll_bar.dart';
import 'package:flowy_infra_ui/style_widget/scrolling/styled_scrollview.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:styled_widget/styled_widget.dart';

import 'application/trash_bloc.dart';
import 'src/trash_cell.dart';

class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const horizontalPadding = 80.0;
    return BlocProvider(
      create: (context) => getIt<TrashBloc>()..add(const TrashEvent.initial()),
      child: BlocBuilder<TrashBloc, TrashState>(
        builder: (context, state) {
          return SizedBox.expand(
            child: Column(
              children: [
                _renderTopBar(context, state),
                const VSpace(32),
                _renderTrashList(context, state),
              ],
            ).padding(horizontal: horizontalPadding, vertical: 48),
          );
        },
      ),
    );
  }

  Widget _renderTrashList(BuildContext context, TrashState state) {
    const barSize = 6.0;
    return Expanded(
      child: ScrollbarListStack(
        axis: Axis.vertical,
        controller: _scrollController,
        scrollbarPadding: EdgeInsets.only(top: TrashSizes.headerHeight),
        barSize: barSize,
        child: StyledSingleChildScrollView(
          barSize: barSize,
          axis: Axis.horizontal,
          child: SizedBox(
            width: TrashSizes.totalWidth,
            child: ScrollConfiguration(
              behavior: const ScrollBehavior().copyWith(scrollbars: false),
              child: CustomScrollView(
                shrinkWrap: true,
                physics: StyledScrollPhysics(),
                controller: _scrollController,
                slivers: [
                  _renderListHeader(context, state),
                  _renderListBody(context, state),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _renderTopBar(BuildContext context, TrashState state) {
    final theme = AppFlowyTheme.of(context);

    return SizedBox(
      height: 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: theme.spacing.s,
        children: [
          Expanded(
            child: Text(
              LocaleKeys.trash_text.tr(),
              style: theme.textStyle.heading2.prominent(
                color: theme.textColorScheme.primary,
              ),
            ),
          ),
          AFGhostButton.normal(
            builder: (context, isHovering, disabled) {
              return Row(
                spacing: theme.spacing.m,
                children: [
                  FlowySvg(
                    FlowySvgs.restore_s,
                    size: const Size.square(20),
                    color: disabled
                        ? theme.iconColorScheme.tertiary
                        : theme.iconColorScheme.primary,
                  ),
                  Text(
                    LocaleKeys.trash_restoreAll.tr(),
                    style: theme.textStyle.body.enhanced(
                      color: disabled
                          ? theme.textColorScheme.tertiary
                          : theme.textColorScheme.primary,
                    ),
                  ),
                ],
              );
            },
            disabled: state.objects.isEmpty,
            onTap: () => showCancelAndConfirmDialog(
              context: context,
              confirmLabel: LocaleKeys.trash_restore.tr(),
              title: LocaleKeys.trash_confirmRestoreAll_title.tr(),
              description: LocaleKeys.trash_confirmRestoreAll_caption.tr(),
              onConfirm: (_) =>
                  context.read<TrashBloc>().add(const TrashEvent.restoreAll()),
            ),
          ),
          AFGhostButton.normal(
            builder: (context, isHovering, disabled) {
              return Row(
                spacing: theme.spacing.m,
                children: [
                  FlowySvg(
                    FlowySvgs.delete_s,
                    size: const Size.square(20),
                    color: disabled
                        ? theme.iconColorScheme.tertiary
                        : theme.iconColorScheme.primary,
                  ),
                  Text(
                    LocaleKeys.trash_deleteAll.tr(),
                    style: theme.textStyle.body.enhanced(
                      color: disabled
                          ? theme.textColorScheme.tertiary
                          : theme.textColorScheme.primary,
                    ),
                  ),
                ],
              );
            },
            disabled: state.objects.isEmpty,
            onTap: () => showConfirmDeletionDialog(
              context: context,
              name: LocaleKeys.trash_confirmDeleteAll_title.tr(),
              description: LocaleKeys.trash_confirmDeleteAll_caption.tr(),
              onConfirm: () =>
                  context.read<TrashBloc>().add(const TrashEvent.deleteAll()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _renderListHeader(BuildContext context, TrashState state) {
    return SliverPersistentHeader(
      delegate: TrashHeaderDelegate(),
      floating: true,
      pinned: true,
    );
  }

  Widget _renderListBody(BuildContext context, TrashState state) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          final object = state.objects[index];
          return SizedBox(
            height: 42,
            child: TrashCell(
              object: object,
              onRestore: () => showCancelAndConfirmDialog(
                context: context,
                title:
                    LocaleKeys.trash_restorePage_title.tr(args: [object.name]),
                description: LocaleKeys.trash_restorePage_caption.tr(),
                confirmLabel: LocaleKeys.trash_restore.tr(),
                onConfirm: (_) => context
                    .read<TrashBloc>()
                    .add(TrashEvent.putback(object.id)),
              ),
              onDelete: () => showConfirmDeletionDialog(
                context: context,
                name: object.name.trim().isEmpty
                    ? LocaleKeys.menuAppHeader_defaultNewPageName.tr()
                    : object.name,
                description:
                    LocaleKeys.deletePagePrompt_deletePermanentDescription.tr(),
                onConfirm: () =>
                    context.read<TrashBloc>().add(TrashEvent.delete(object)),
              ),
            ),
          );
        },
        childCount: state.objects.length,
        addAutomaticKeepAlives: false,
      ),
    );
  }
}
