import 'package:appflowy/util/int64_extension.dart';
import 'package:appflowy/workspace/application/settings/appearance/appearance_cubit.dart';
import 'package:appflowy/workspace/application/settings/billing/settings_workspace_sub_billing_bloc.dart';
import 'package:appflowy/workspace/application/settings/date_time/date_format_ext.dart';
import 'package:appflowy/workspace/application/settings/plan/workspace_subscription_ext.dart';
import 'package:appflowy/workspace/presentation/settings/pages/settings_billing_view/widgets/change_period_dialog.dart';
import 'package:appflowy/workspace/presentation/settings/shared/single_setting_action.dart';
import 'package:appflowy/workspace/presentation/home/menu/sidebar/space/shared_widget.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../../generated/locale_keys.g.dart';
import 'constants.dart';

/// Widget that displays AI addon subscription information and management options
class WorkspaceSubscriptionAIAddonTile extends StatelessWidget {
  const WorkspaceSubscriptionAIAddonTile({
    super.key,
    required this.label,
    required this.description,
    required this.canceledDescription,
    required this.activeDescription,
    required this.plan,
    this.subscriptionInfo,
  });

  final String label;
  final String description;
  final String canceledDescription;
  final String activeDescription;
  final SubscriptionPlanPB plan;
  final WorkspaceAddOnPB? subscriptionInfo;

  @override
  Widget build(BuildContext context) {
    final isCanceled = subscriptionInfo?.addOnSubscription.status ==
        SubscriptionStatusPB.Canceled;

    final dateFormat = context.read<AppearanceSettingsCubit>().state.dateFormat;

    return Column(
      children: [
        _buildMainAction(context, isCanceled, dateFormat),
        if (subscriptionInfo != null) ...[
          const VSpace(10),
          _buildPeriodAction(context),
        ],
      ],
    );
  }

  Widget _buildMainAction(
    BuildContext context,
    bool isCanceled,
    UserDateFormatPB dateFormat,
  ) {
    return SingleSettingAction(
      label: label,
      description: _getDescription(isCanceled, dateFormat),
      buttonLabel: _getButtonLabel(isCanceled),
      fontWeight: FontWeight.w500,
      minWidth: kBillingButtonsMinWidth,
      onPressed: () => _handleMainAction(context),
    );
  }

  String _getDescription(bool isCanceled, UserDateFormatPB dateFormat) {
    if (subscriptionInfo == null) {
      return description.tr();
    }

    final endDate = dateFormat.formatDate(
      subscriptionInfo!.addOnSubscription.endDate.toDateTime(),
      false,
    );

    return isCanceled
        ? canceledDescription.tr(args: [endDate])
        : activeDescription.tr(args: [endDate]);
  }

  String _getButtonLabel(bool isCanceled) {
    if (subscriptionInfo == null) {
      return LocaleKeys.settings_billingPage_addons_addLabel.tr();
    }
    return isCanceled
        ? LocaleKeys.settings_billingPage_addons_renewLabel.tr()
        : LocaleKeys.settings_billingPage_addons_removeLabel.tr();
  }

  Future<void> _handleMainAction(BuildContext context) async {
    if (subscriptionInfo != null) {
      await _showRemoveAddonDialog(context);
    } else {
      _addAddon(context);
    }
  }

  Future<void> _showRemoveAddonDialog(BuildContext context) async {
    await showConfirmDialog(
      context: context,
      style: ConfirmPopupStyle.cancelAndOk,
      title: LocaleKeys.settings_billingPage_addons_removeDialog_title
          .tr(args: [plan.label]),
      description: LocaleKeys
          .settings_billingPage_addons_removeDialog_description
          .tr(namedArgs: {"plan": plan.label.tr()}),
      confirmLabel: LocaleKeys.button_confirm.tr(),
      onConfirm: (_) => _cancelAddon(context),
    );
  }

  void _addAddon(BuildContext context) {
    context
        .read<SettingsWorkspaceSubscriptionBillingBloc>()
        .add(SettingsWorkspaceSubscriptionBillingEvent.addSubscription(plan));
  }

  void _cancelAddon(BuildContext context) {
    context.read<SettingsWorkspaceSubscriptionBillingBloc>().add(
          SettingsWorkspaceSubscriptionBillingEvent.cancelSubscription(plan),
        );
  }

  Widget _buildPeriodAction(BuildContext context) {
    return SingleSettingAction(
      label: LocaleKeys.settings_billingPage_planPeriod.tr(
        args: [subscriptionInfo!.addOnSubscription.subscriptionPlan.label],
      ),
      description: subscriptionInfo!.addOnSubscription.interval.label,
      buttonLabel: LocaleKeys.settings_billingPage_plan_periodButtonLabel.tr(),
      minWidth: kBillingButtonsMinWidth,
      onPressed: () => _showChangePeriodDialog(context),
    );
  }

  void _showChangePeriodDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => ChangePeriodDialog(
        currentPlan: subscriptionInfo!.addOnSubscription.subscriptionPlan,
        currentInterval: subscriptionInfo!.addOnSubscription.interval,
        onConfirm: (newInterval) {
          if (newInterval != subscriptionInfo!.addOnSubscription.interval) {
            context.read<SettingsWorkspaceSubscriptionBillingBloc>().add(
                  SettingsWorkspaceSubscriptionBillingEvent.updatePeriod(
                    plan: subscriptionInfo!.addOnSubscription.subscriptionPlan,
                    interval: newInterval,
                  ),
                );
          }
        },
      ),
    );
  }
}
