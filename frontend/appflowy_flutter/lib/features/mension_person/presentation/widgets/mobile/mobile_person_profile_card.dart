import 'package:appflowy/core/helpers/url_launcher.dart';
import 'package:appflowy/features/mension_person/data/models/person.dart';
import 'package:appflowy/features/mension_person/logic/person_bloc.dart';
import 'package:appflowy/features/mension_person/presentation/widgets/person/default_profile_banner.dart';
import 'package:appflowy/features/mension_person/presentation/widgets/person/person_profile_card.dart';
import 'package:appflowy/features/mension_person/presentation/widgets/profile_card_more_button.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:universal_platform/universal_platform.dart';

class MobilePersonProfileCard extends StatefulWidget {
  const MobilePersonProfileCard({super.key});

  @override
  State<MobilePersonProfileCard> createState() =>
      _MobilePersonProfileCardState();
}

class _MobilePersonProfileCardState extends State<MobilePersonProfileCard> {
  final popoverController = PopoverController();

  @override
  void dispose() {
    hidePopover();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildCard(context);
  }

  Widget buildCard(BuildContext context) {
    final personState = context.read<PersonBloc>().state,
        person = personState.person;
    if (personState.isLoading) {
      return Center(child: CircularProgressIndicator.adaptive());
    }

    if (person.deleted) {
      return context.buildDeletedPerson();
    }
    return buildNormalPerson();
  }

  Widget buildNormalPerson() {
    final theme = AppFlowyTheme.of(context),
        spacing = theme.spacing,
        xl = spacing.xl;
    final sizeWidth = MediaQuery.of(context).size.width;
    return SizedBox(
      width: sizeWidth,
      child: Padding(
        padding: EdgeInsets.fromLTRB(xl, 0, xl, 0),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                buildCover(context),
                VSpace(64),
                buildPersonInfo(context),
              ],
            ),
            Positioned(
              left: UniversalPlatform.isMobile ? 36 : xl,
              top: 38,
              child: context.buildAvatar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCover(BuildContext context) => DefaultAssetProfileBanner();

  Widget buildPersonInfo(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        context.buildPersonName(),
        context.buildPersonEmail(),
        context.buildPersonDescription(),
        VSpace(theme.spacing.xxl),
        context.buildActions(
          moreButton:
              ProfileCardMoreButton(popoverController: popoverController),
        ),
      ],
    );
  }

  Widget buildEmail(BuildContext context) {
    final person = context.read<PersonBloc>().state.personWithAccess;
    final theme = AppFlowyTheme.of(context);
    return Text(
      person.person.email,
      style:
          theme.textStyle.body.standard(color: theme.textColorScheme.secondary),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Decoration buildCardDecoration(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return BoxDecoration(
      color: theme.surfaceColorScheme.layer01,
      borderRadius: BorderRadius.circular(theme.spacing.l),
      boxShadow: theme.shadow.small,
    );
  }

  void openEmailApp(Person person) {
    afLaunchUrlString('mailto:${person.email}');
  }

  void hidePopover() {
    popoverController.close();
  }
}
