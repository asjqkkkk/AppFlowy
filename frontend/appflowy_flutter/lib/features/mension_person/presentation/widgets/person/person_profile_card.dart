import 'package:appflowy/core/helpers/url_launcher.dart';
import 'package:appflowy/features/mension_person/logic/person_bloc.dart';
import 'package:appflowy/features/mension_person/presentation/widgets/person/person_role_badge.dart';
import 'package:appflowy/features/mension_person/presentation/widgets/profile_card_more_button.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/base/string_extension.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:universal_platform/universal_platform.dart';

import 'default_profile_banner.dart';
import 'svg_path_avatar.dart';

class PersonProfileCard extends StatefulWidget {
  const PersonProfileCard({
    super.key,
    required this.triggerSize,
    required this.showAtBottom,
    required this.globalOffset,
    required this.editorState,
    required this.person,
    this.blockId,
    this.onEnter,
    this.onExit,
  });

  final Size triggerSize;
  final bool showAtBottom;
  final Offset globalOffset;
  final EditorState editorState;
  final MentionablePersonPB person;
  final String? blockId;
  final PointerEnterEventListener? onEnter;
  final PointerExitEventListener? onExit;

  @override
  State<PersonProfileCard> createState() => _PersonProfileCardState();
}

class _PersonProfileCardState extends State<PersonProfileCard> {
  final popoverController = PopoverController();

  MentionablePersonPB get person => widget.person;
  Offset get globalOffset => widget.globalOffset;
  EditorState get editorState => widget.editorState;
  Size get triggerSize => widget.triggerSize;

  @override
  void dispose() {
    hidePopover();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editorSize = editorState.renderBox?.size ?? Size.zero,
        editorOffset =
            editorState.renderBox?.localToGlobal(Offset.zero) ?? Offset.zero,
        triggerWidth = triggerSize.width,
        triggerHeight = triggerSize.height,
        menuWidth = 280.0;
    final List<_PlaceHolder> placeHolders = [];
    final overflowRight =
        globalOffset.dx + menuWidth >= editorOffset.dx + editorSize.width;
    if (!overflowRight) {
      placeHolders.add(_PlaceHolder(triggerSize, true));
      if (triggerWidth < menuWidth) {
        placeHolders.add(
          _PlaceHolder(Size(menuWidth - triggerWidth, triggerHeight), false),
        );
      }
    } else {
      final startX = editorOffset.dx + editorSize.width - menuWidth;
      final unhoveredWidth =
          globalOffset.dx - startX + AppFlowyTheme.of(context).spacing.m;
      placeHolders
          .add(_PlaceHolder(Size(unhoveredWidth, triggerHeight), false));
      placeHolders.add(_PlaceHolder(triggerSize, true));
      final remianingWidth = menuWidth - unhoveredWidth - triggerWidth;
      if (remianingWidth > 0) {
        placeHolders.add(
          _PlaceHolder(Size(remianingWidth, triggerHeight), false),
        );
      }
    }

    final mouseRegionPlaceHolder = Row(
      children: [
        ...List.generate(placeHolders.length, (index) {
          final placeHolder = placeHolders[index],
              enableHovering = placeHolder.enableHovering;
          return MouseRegion(
            cursor: enableHovering
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            onEnter: enableHovering
                ? null
                : (e) => widget.onExit?.call(PointerExitEvent()),
            child: Container(
              width: placeHolder.size.width,
              height: placeHolder.size.height,
              color: Colors.black.withAlpha(1),
            ),
          );
        }),
      ],
    );
    return GestureDetector(
      onTap: hidePopover,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: widget.showAtBottom
            ? [mouseRegionPlaceHolder, buildDecoratedCard(context)]
            : [buildDecoratedCard(context), mouseRegionPlaceHolder],
      ),
    );
  }

  Widget buildDecoratedCard(BuildContext context) => DecoratedBox(
        decoration: buildCardDecoration(context),
        child: buildCard(context),
      );

  Widget buildCard(BuildContext context) {
    final theme = AppFlowyTheme.of(context), xxl = theme.spacing.xxl;
    final personState = context.read<PersonBloc>().state;
    if (!personState.isIdle) return const SizedBox.shrink();
    if (personState.isDeleted(person)) {
      return context.buildDeletedPerson();
    }

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            buildCover(context),
            SizedBox(
              width: 280,
              child: Padding(
                padding: EdgeInsets.fromLTRB(xxl, 60.0, xxl, xxl),
                child: buildPersonInfo(context),
              ),
            ),
          ],
        ),
        Positioned(
          left: xxl,
          top: 38.0,
          child: context.buildAvatar(person),
        ),
      ],
    );
  }

  Widget buildCover(BuildContext context) {
    final theme = AppFlowyTheme.of(context), m = theme.spacing.m;

    /// TODO: replace it as banner widget after supporting profile setting
    return Container(
      padding: EdgeInsets.fromLTRB(m, m, m, 0),
      child: DefaultAssetProfileBanner(),
    );
    // final personState = context.read<PersonBloc>().state;
    // final person = personState.personWithAccess.person,
    //     url = person.coverImageUrl ?? '';
    // if (url.isEmpty) return VSpace(100);
    // final theme = AppFlowyTheme.of(context), spaceM = theme.spacing.m;
    // return Container(
    //   width: 280,
    //   height: 88,
    //   padding: EdgeInsets.fromLTRB(spaceM, spaceM, spaceM, 0),
    //   child: ClipRRect(
    //     borderRadius: BorderRadius.circular(theme.spacing.m),
    //     child: CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
    //   ),
    // );
  }

  Widget buildPersonInfo(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    final personState = context.read<PersonBloc>().state;
    final isDeleted = personState.isDeleted(person);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        context.buildPersonName(person, isDeleted),
        context.buildPersonEmail(person, isDeleted),
        context.buildPersonDescription(person, isDeleted),
        VSpace(theme.spacing.xxl),
        buildActions(context),
      ],
    );
  }

  Widget buildEmail(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return Text(
      person.email,
      style:
          theme.textStyle.body.standard(color: theme.textColorScheme.secondary),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget buildActions(BuildContext context) => context.buildActions(
        person: person,
        blockId: widget.blockId,
        moreButton: ProfileCardMoreButton(
          person: person,
          onEnter: widget.onEnter,
          onExit: widget.onExit,
          popoverController: popoverController,
        ),
      );

  Decoration buildCardDecoration(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return BoxDecoration(
      color: theme.surfaceColorScheme.layer01,
      borderRadius: BorderRadius.circular(theme.spacing.l),
      boxShadow: theme.shadow.small,
    );
  }

  void openEmailApp(MentionablePersonPB person) {
    afLaunchUrlString('mailto:${person.email}');
  }

  void hidePopover() {
    popoverController.close();
  }
}

extension PersonProfileCardWidgetExtension on BuildContext {
  Widget buildPersonName(MentionablePersonPB person, bool isDeleted) {
    final theme = AppFlowyTheme.of(this);
    final suffixIcon = buildSuffixIcon(person);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            person.name,
            style: theme.textStyle.title.prominent(
              color: isDeleted
                  ? theme.textColorScheme.tertiary
                  : theme.textColorScheme.primary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (suffixIcon != null) suffixIcon,
      ],
    );
  }

  Widget buildPersonEmail(MentionablePersonPB person, bool isDeleted) {
    final theme = AppFlowyTheme.of(this);
    return Text(
      person.email,
      style: theme.textStyle.body.standard(
        color: isDeleted
            ? theme.textColorScheme.tertiary
            : theme.textColorScheme.secondary,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget buildPersonDescription(MentionablePersonPB person, bool isDeleted) {
    final description = person.description;
    if (description.isEmpty) return const SizedBox.shrink();
    final theme = AppFlowyTheme.of(this);
    return Container(
      margin: EdgeInsets.only(top: theme.spacing.m),
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.fillColorScheme.contentVisible,
          borderRadius: BorderRadius.circular(theme.spacing.m),
        ),
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.l),
          child: Text(
            description,
            style: theme.textStyle.caption.standard(
              color: isDeleted
                  ? theme.textColorScheme.tertiary
                  : theme.textColorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget? buildSuffixIcon(MentionablePersonPB person) {
    final theme = AppFlowyTheme.of(this);
    if (person.role == MentionablePersonTypePB.Contact) {
      return FlowySvg(
        FlowySvgs.contact_suffix_icon_m,
        color: theme.iconColorScheme.tertiary,
        blendMode: null,
        size: Size.square(20),
      );
    }
    return null;
  }

  Widget buildNotificationButton(MentionablePersonPB person, String? blockId) {
    final theme = AppFlowyTheme.of(this);
    final personBloc = read<PersonBloc>();
    if (personBloc.state.isDeleted(person)) return const SizedBox.shrink();
    final hasAccess = personBloc.state.hasAccess(person.email),
        isContact = person.role == MentionablePersonTypePB.Contact;
    if (isContact) {
      return FlowyTooltip(
        message: LocaleKeys.document_mentionMenu_emailButtonTooltip.tr(),
        preferBelow: false,
        child: AFOutlinedButton.normal(
          padding:
              EdgeInsets.all(UniversalPlatform.isMobile ? 10 : theme.spacing.s),
          builder: (context, hovering, disabled) {
            return FlowySvg(
              FlowySvgs.mention_send_email_m,
              size: Size.square(20),
              color: theme.iconColorScheme.primary,
            );
          },
          onTap: () => afLaunchUrlString('mailto:${person.email}'),
        ),
      );
    }
    if (!hasAccess) {
      return const SizedBox.shrink();

      /// TODO: replace it with invite button after supporting inviting
      // return ProfileInviteButton(onTap: () {});
    }
    return FlowyTooltip(
      message: LocaleKeys.document_mentionMenu_notificationButtonTooltip.tr(),
      preferBelow: false,
      child: AFOutlinedButton.normal(
        padding:
            EdgeInsets.all(UniversalPlatform.isMobile ? 10 : theme.spacing.s),
        builder: (context, hovering, disabled) {
          return FlowySvg(
            FlowySvgs.mention_send_notification_m,
            size: Size.square(20),
            color: theme.iconColorScheme.primary,
          );
        },
        onTap: () {
          personBloc.add(
            PersonEvent.notifyPerson(
              blockId: blockId,
              person: person,
              ancestorId: '',
            ),
          );
        },
      ),
    );
  }

  Widget buildAvatar(MentionablePersonPB person) {
    final personState = read<PersonBloc>().state;
    final hasAccess = personState.hasAccess(person.email);
    final url = person.avatarUrl,
        noAccess = !personState.isDeleted(person) &&
            !hasAccess &&
            person.role != MentionablePersonTypePB.Contact;
    final isEmojiAvatar = url.isNotEmpty && !url.startsWith('http');
    final theme = AppFlowyTheme.of(this);
    const size = 90.0;
    Widget avatar = SizedBox.square(
      dimension: size,
      child: PathWidgetMask(
        child: AFAvatar(
          url: url,
          radius: 0,
          name: person.name,
          size: AFAvatarSize.xl,
          backgroundColor:
              (url.isNotEmpty && !isEmojiAvatar) ? Colors.transparent : null,
        ),
      ),
    );
    if (noAccess) {
      avatar = FlowyTooltip(
        message: LocaleKeys.document_mentionMenu_noAccessTooltip.tr(),
        preferBelow: false,
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            children: [
              avatar,
              PathWidgetMask(
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: theme.surfaceColorScheme.overlay,
                  ),
                  child: Center(
                    child: FlowySvg(
                      FlowySvgs.profile_card_avatar_no_access_m,
                      size: Size.square(20),
                      color: theme.iconColorScheme.onFill,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return PathWidgetMask(
      path: avatarContainerPath,
      child: DecoratedBox(
        decoration: BoxDecoration(color: theme.surfaceColorScheme.layer01),
        child: SizedBox.square(
          dimension: size + 10,
          child: Center(child: avatar),
        ),
      ),
    );
  }

  Widget buildDeletedPerson() {
    final theme = AppFlowyTheme.of(this),
        spacing = theme.spacing,
        m = spacing.m,
        xl = spacing.xl;
    const size = 100.0, radius = 43.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(theme.spacing.l),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: UniversalPlatform.isMobile
                    ? EdgeInsets.fromLTRB(xl, 0, xl, 0)
                    : EdgeInsets.fromLTRB(m, m, m, 0),
                child: Container(
                  width: UniversalPlatform.isMobile ? double.infinity : 264,
                  height: UniversalPlatform.isMobile ? 92 : 80,
                  decoration: BoxDecoration(
                    color: theme.badgeColorScheme.color20Light1,
                    borderRadius: BorderRadius.circular(theme.spacing.m),
                  ),
                ),
              ),
              SizedBox(
                height: 108,
                child: Padding(
                  padding: EdgeInsets.only(top: 60, left: 20),
                  child: Text(
                    LocaleKeys.document_mentionMenu_deleted.tr().capitalize(),
                    style: theme.textStyle.title
                        .prominent(color: theme.textColorScheme.tertiary),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: UniversalPlatform.isMobile ? 36 : 20,
            top: 38,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: theme.surfaceColorScheme.layer01,
                borderRadius: BorderRadius.circular(radius),
              ),
              child: Center(
                child: Container(
                  width: size - 10,
                  height: size - 10,
                  decoration: BoxDecoration(
                    color: theme.surfaceColorScheme.layer01,
                    borderRadius: BorderRadius.circular(
                      radius * 2 / (size - 10) * (radius - 2),
                    ),
                    border: Border.all(color: theme.borderColorScheme.primary),
                  ),
                  child: Center(
                    child: FlowySvg(
                      FlowySvgs.user_deleted_icon_lg,
                      color: theme.iconColorScheme.secondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildActions({
    required ProfileCardMoreButton moreButton,
    required MentionablePersonPB person,
    String? blockId,
  }) {
    final state = read<PersonBloc>().state;
    if (!state.isIdle) return const SizedBox.shrink();
    final theme = AppFlowyTheme.of(this);

    return Row(
      children: [
        PersonRoleBadge(
          person: person,
          access: state.hasAccess(person.email),
          isDeleted: state.isDeleted(person),
        ),
        Spacer(),
        buildNotificationButton(person, blockId),
        HSpace(theme.spacing.m),
        moreButton,
      ],
    );
  }
}

class _PlaceHolder {
  _PlaceHolder(this.size, this.enableHovering);
  final Size size;
  final bool enableHovering;
}
