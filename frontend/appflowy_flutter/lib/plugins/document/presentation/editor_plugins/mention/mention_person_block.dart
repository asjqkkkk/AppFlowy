import 'package:appflowy/features/mension_person/data/models/person.dart';
import 'package:appflowy/features/mension_person/logic/person_bloc.dart';
import 'package:appflowy/features/mension_person/presentation/widgets/hover_menu.dart';
import 'package:appflowy/features/mension_person/presentation/widgets/mobile/mobile_person_profile_card.dart';
import 'package:appflowy/features/mension_person/presentation/widgets/person/person_profile_card.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/drag_handle.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/show_mobile_bottom_sheet.dart';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:universal_platform/universal_platform.dart';

class MentionPersonBlock extends StatefulWidget {
  const MentionPersonBlock({
    super.key,
    required this.editorState,
    required this.personId,
    required this.pageId,
    required this.blockId,
    required this.node,
    required this.textStyle,
    required this.index,
  });

  final EditorState editorState;
  final String personId;
  final String pageId;
  final String? blockId;
  final Node node;
  final TextStyle? textStyle;

  // Used to update the block
  final int index;

  @override
  State<MentionPersonBlock> createState() => _MentionPersonBlockState();
}

class _MentionPersonBlockState extends State<MentionPersonBlock> {
  final key = GlobalKey();
  Size triggerSize = Size.zero;
  double positionY = 0;
  bool showAtBottom = false;
  RenderBox? get box => key.currentContext?.findRenderObject() as RenderBox?;

  String get personId => widget.personId;
  String get pageId => widget.pageId;
  String? get blockId => widget.blockId;

  @override
  void initState() {
    super.initState();
    checkForPositionAndSize();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PersonBloc, PersonState>(
      key: key,
      builder: (context, state) {
        final bloc = context.read<PersonBloc>();
        return HoverMenu(
          key: ValueKey(
            showAtBottom.hashCode & positionY.hashCode & triggerSize.hashCode,
          ),
          enable: UniversalPlatform.isDesktop,
          menuConstraints: BoxConstraints(
            maxHeight: 420,
            maxWidth: 280,
            minWidth: 280,
          ),
          triggerSize: triggerSize,
          direction: showAtBottom
              ? PopoverDirection.bottomWithLeftAligned
              : PopoverDirection.topWithLeftAligned,
          offset: Offset(
            0,
            showAtBottom ? -triggerSize.height : triggerSize.height,
          ),
          menuBuilder: (context, onEnter, onExit) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: bloc),
            ],
            child: BlocBuilder<PersonBloc, PersonState>(
              builder: (context, state) => PersonProfileCard(
                person: bloc.state.persons.firstWhere(
                  (e) => e.id == personId,
                  orElse: () =>
                      Person.empty().copyWith(id: personId, deleted: true),
                ),
                triggerSize: triggerSize,
                showAtBottom: showAtBottom,
                onEnter: onEnter,
                onExit: onExit,
              ),
            ),
          ),
          child: buildPerson(context),
        );
      },
    );
  }

  Widget buildPerson(BuildContext context) {
    final bloc = context.read<PersonBloc>(), state = bloc.state;
    final person = state.persons.firstWhere(
      (p) => p.id == personId,
      orElse: () => Person.empty().copyWith(id: personId, deleted: true),
    );
    final theme = AppFlowyTheme.of(context);
    final color = theme.textColorScheme.secondary;
    final style = widget.textStyle?.copyWith(
          color: color,
          leadingDistribution: TextLeadingDistribution.even,
        ) ??
        theme.textStyle.body.standard(color: color);
    if (state.isLoading) {
      return SizedBox(
        height: style.fontSize ?? 22,
        child: CircularProgressIndicator.adaptive(),
      );
    }

    Widget richText;
    if (person.deleted) {
      richText = buildDeletedPerson(context);
    } else if (person.isEmpty) {
      richText = buildErrorPerson(context);
    } else {
      richText = buildNormalPerson(context, person.name);
    }
    richText = Padding(
      padding: EdgeInsets.only(right: theme.spacing.m),
      child: richText,
    );
    return UniversalPlatform.isMobile
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              /// hide the keyboard if [MobilePersonProfileCard] is open
              SystemChannels.textInput.invokeMethod('TextInput.hide');
              showMobileBottomSheet(
                context,
                dragHandleBuilder: (_) => const DragHandleV2(),
                showDragHandle: true,
                showDivider: false,
                showHeader: true,
                showCloseButton: true,
                title: LocaleKeys.document_mentionMenu_profileCard.tr(),
                backgroundColor: theme.surfaceColorScheme.primary,
                builder: (_) => BlocProvider.value(
                  value: bloc,
                  child: MobilePersonProfileCard(person: person),
                ),
              );
            },
            child: richText,
          )
        : richText;
  }

  Widget buildDeletedPerson(BuildContext context) {
    final theme = AppFlowyTheme.of(context),
        color = theme.textColorScheme.tertiary,
        style = widget.textStyle?.copyWith(
              color: color,
              leadingDistribution: TextLeadingDistribution.even,
            ) ??
            theme.textStyle.body.standard(color: color);
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '@',
            style: style.copyWith(
              color: theme.textColorScheme.tertiary,
            ),
          ),
          TextSpan(
            text: LocaleKeys.document_mentionMenu_deleted.tr(),
            style: style,
          ),
        ],
      ),
    );
  }

  Widget buildErrorPerson(BuildContext context) {
    final theme = AppFlowyTheme.of(context),
        color = theme.textColorScheme.error,
        style = widget.textStyle?.copyWith(
              color: color,
              leadingDistribution: TextLeadingDistribution.even,
            ) ??
            theme.textStyle.body.standard(color: color);
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '@',
            style: style.copyWith(
              color: theme.textColorScheme.tertiary,
            ),
          ),
          TextSpan(
            text: LocaleKeys.invitation_errorModal_title.tr(),
            style: style,
          ),
        ],
      ),
    );
  }

  Widget buildNormalPerson(BuildContext context, String name) {
    final theme = AppFlowyTheme.of(context),
        color = theme.textColorScheme.secondary,
        style = widget.textStyle?.copyWith(
              color: color,
              leadingDistribution: TextLeadingDistribution.even,
            ) ??
            theme.textStyle.body.standard(color: color);
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '@',
            style: style.copyWith(
              color: theme.textColorScheme.tertiary,
            ),
          ),
          TextSpan(text: name, style: style),
        ],
      ),
    );
  }

  void checkForPositionAndSize() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderBox = box;
      if (renderBox is RenderBox) {
        final position = renderBox.localToGlobal(Offset.zero);
        if (mounted) {
          setState(() {
            triggerSize = renderBox.size;
            positionY = position.dy;
          });
        }
        if (positionY < 300) {
          changeDirection(true);
        } else {
          changeDirection(false);
        }
      }
      checkForPositionAndSize();
    });
  }

  void changeDirection(bool bottom) {
    if (showAtBottom == bottom) return;
    if (mounted) {
      setState(() {
        showAtBottom = bottom;
      });
    }
  }
}
