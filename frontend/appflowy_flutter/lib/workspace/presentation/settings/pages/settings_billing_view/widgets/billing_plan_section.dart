import 'package:appflowy/workspace/application/settings/billing/settings_workspace_sub_billing_bloc.dart';
import 'package:appflowy/workspace/application/settings/plan/workspace_subscription_ext.dart';
import 'package:appflowy/workspace/presentation/settings/pages/settings_billing_view/widgets/change_period_dialog.dart';
import 'package:appflowy/workspace/presentation/settings/shared/settings_category.dart';
import 'package:appflowy/workspace/presentation/settings/shared/single_setting_action.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../../generated/locale_keys.g.dart';
import 'constants.dart';

/// Widget that displays the current billing plan and allows users to change it
class BillingPlanSection extends StatelessWidget {
  const BillingPlanSection({
    super.key,
    required this.subscriptionInfo,
    required this.onChangePlan,
    required this.billingPortalEnabled,
  });

  final WorkspaceSubscriptionInfoPB subscriptionInfo;
  final VoidCallback onChangePlan;
  final bool billingPortalEnabled;

  @override
  Widget build(BuildContext context) {
    return SettingsCategory(
      title: LocaleKeys.settings_billingPage_plan_title.tr(),
      children: [
        SingleSettingAction(
          onPressed: onChangePlan,
          fontWeight: FontWeight.w500,
          label: subscriptionInfo.label,
          buttonLabel:
              LocaleKeys.settings_billingPage_plan_planButtonLabel.tr(),
          minWidth: kBillingButtonsMinWidth,
        ),
        if (billingPortalEnabled) _buildBillingPeriodSetting(context),
      ],
    );
  }

  Widget _buildBillingPeriodSetting(BuildContext context) {
    return SingleSettingAction(
      onPressed: () => _showChangePeriodDialog(context),
      label: LocaleKeys.settings_billingPage_plan_billingPeriod.tr(),
      description: subscriptionInfo.subscription.interval.label,
      fontWeight: FontWeight.w500,
      buttonLabel: LocaleKeys.settings_billingPage_plan_periodButtonLabel.tr(),
      minWidth: kBillingButtonsMinWidth,
    );
  }

  void _showChangePeriodDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => ChangePeriodDialog(
        currentPlan: subscriptionInfo.subscription.subscriptionPlan,
        currentInterval: subscriptionInfo.subscription.interval,
        onConfirm: (newInterval) {
          if (newInterval != subscriptionInfo.subscription.interval) {
            context.read<SettingsWorkspaceSubscriptionBillingBloc>().add(
                  SettingsWorkspaceSubscriptionBillingEvent.updatePeriod(
                    plan: subscriptionInfo.subscription.subscriptionPlan,
                    interval: newInterval,
                  ),
                );
          }
        },
      ),
    );
  }
}
