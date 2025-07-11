import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/util/int64_extension.dart';
import 'package:appflowy/workspace/application/settings/appearance/appearance_cubit.dart';
import 'package:appflowy/workspace/application/settings/date_time/date_format_ext.dart';
import 'package:appflowy/workspace/application/settings/plan/settings_plan_bloc.dart';
import 'package:appflowy/workspace/application/settings/plan/workspace_subscription_ext.dart';
import 'package:appflowy/workspace/presentation/settings/pages/settings_plan_comparison_dialog.dart';
import 'package:appflowy/workspace/presentation/settings/shared/flowy_gradient_button.dart';
import 'package:appflowy_backend/protobuf/flowy-user/billing.pb.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/theme_extension.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CurrentPlanBox extends StatefulWidget {
  const CurrentPlanBox({
    super.key,
    required this.subscriptionInfo,
  });

  final WorkspaceSubscriptionInfoPB subscriptionInfo;

  @override
  State<CurrentPlanBox> createState() => _CurrentPlanBoxState();
}

class _CurrentPlanBoxState extends State<CurrentPlanBox> {
  late SettingsPlanBloc planBloc;

  @override
  void initState() {
    super.initState();
    planBloc = context.read<SettingsPlanBloc>();
  }

  @override
  void didChangeDependencies() {
    planBloc = context.read<SettingsPlanBloc>();
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _PlanContainer(
          subscriptionInfo: widget.subscriptionInfo,
          onUpgrade: () => _openPricingDialog(
            context,
            planBloc.workspaceId,
            widget.subscriptionInfo,
          ),
        ),
        const _CurrentPlanBadge(),
      ],
    );
  }

  void _openPricingDialog(
    BuildContext context,
    String workspaceId,
    WorkspaceSubscriptionInfoPB subscriptionInfo,
  ) {
    showDialog(
      context: context,
      builder: (_) => BlocProvider<SettingsPlanBloc>.value(
        value: planBloc,
        child: SettingsPlanComparisonDialog(
          workspaceId: workspaceId,
          subscriptionInfo: subscriptionInfo,
        ),
      ),
    );
  }
}

class _PlanContainer extends StatelessWidget {
  const _PlanContainer({
    required this.subscriptionInfo,
    required this.onUpgrade,
  });

  final WorkspaceSubscriptionInfoPB subscriptionInfo;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFBDBDBD)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 6,
                child: _PlanInfo(subscriptionInfo: subscriptionInfo),
              ),
              Flexible(
                flex: 5,
                child: _UpgradeButton(onPressed: onUpgrade),
              ),
            ],
          ),
          if (subscriptionInfo.isCanceled)
            _CanceledInfo(subscriptionInfo: subscriptionInfo),
        ],
      ),
    );
  }
}

class _PlanInfo extends StatelessWidget {
  const _PlanInfo({required this.subscriptionInfo});

  final WorkspaceSubscriptionInfoPB subscriptionInfo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VSpace(4),
        FlowyText.semibold(
          subscriptionInfo.label,
          fontSize: 24,
          color: AFThemeExtension.of(context).strongText,
        ),
        const VSpace(8),
        FlowyText.regular(
          subscriptionInfo.info,
          fontSize: 14,
          color: AFThemeExtension.of(context).strongText,
          maxLines: 3,
        ),
      ],
    );
  }
}

class _UpgradeButton extends StatelessWidget {
  const _UpgradeButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: FlowyGradientButton(
            label:
                LocaleKeys.settings_planPage_planUsage_currentPlan_upgrade.tr(),
            onPressed: onPressed,
          ),
        ),
      ],
    );
  }
}

class _CanceledInfo extends StatelessWidget {
  const _CanceledInfo({required this.subscriptionInfo});

  final WorkspaceSubscriptionInfoPB subscriptionInfo;

  @override
  Widget build(BuildContext context) {
    final appearance = context.read<AppearanceSettingsCubit>().state;
    final canceledDate = appearance.dateFormat.formatDate(
      subscriptionInfo.subscription.endDate.toDateTime(),
      false,
    );

    return Column(
      children: [
        const VSpace(12),
        FlowyText(
          LocaleKeys.settings_planPage_planUsage_currentPlan_canceledInfo.tr(
            args: [canceledDate],
          ),
          maxLines: 5,
          fontSize: 12,
          color: Theme.of(context).colorScheme.error,
        ),
      ],
    );
  }
}

class _CurrentPlanBadge extends StatelessWidget {
  const _CurrentPlanBadge();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: const BoxDecoration(
          color: Color(0xFF4F3F5F),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Center(
          child: FlowyText.semibold(
            LocaleKeys.settings_planPage_planUsage_currentPlan_bannerLabel.tr(),
            fontSize: 14,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
