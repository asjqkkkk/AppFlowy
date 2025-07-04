import 'package:appflowy/features/shared_section/logic/shared_section_bloc.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/workspace/presentation/home/home_sizes.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/style_widget/text.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

ValueNotifier<bool> refreshSharedSectionNotifier = ValueNotifier(false);

class MSharedSectionHeader extends StatefulWidget {
  const MSharedSectionHeader({
    super.key,
  });

  @override
  State<MSharedSectionHeader> createState() => _MSharedSectionHeaderState();
}

class _MSharedSectionHeaderState extends State<MSharedSectionHeader> {
  @override
  void initState() {
    super.initState();

    refreshSharedSectionNotifier.addListener(_onRefresh);
  }

  @override
  void dispose() {
    refreshSharedSectionNotifier.removeListener(_onRefresh);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          const HSpace(HomeSpaceViewSizes.mHorizontalPadding),
          FlowySvg(
            FlowySvgs.shared_with_me_m,
            color: theme.badgeColorScheme.color13Thick2,
          ),
          const HSpace(10.0),
          FlowyText.medium(
            LocaleKeys.shareSection_shared.tr(),
            lineHeight: 1.15,
            fontSize: 16.0,
          ),
          const HSpace(HomeSpaceViewSizes.mHorizontalPadding),
        ],
      ),
    );
  }

  void _onRefresh() {
    context.read<SharedSectionBloc>().add(const SharedSectionEvent.refresh());
  }
}
