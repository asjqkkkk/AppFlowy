import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/workspace/application/settings/plan/settings_plan_bloc.dart';
import 'package:appflowy/workspace/application/settings/plan/workspace_subscription_ext.dart';
import 'package:appflowy/workspace/application/settings/plan/workspace_usage_ext.dart';
import 'package:appflowy/workspace/presentation/settings/pages/settings_plan_view/widgets/toggle_more.dart';
import 'package:appflowy/workspace/presentation/settings/pages/settings_plan_view/widgets/usage_box.dart';
import 'package:appflowy_backend/protobuf/flowy-user/billing.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/workspace.pb.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/theme_extension.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PlanUsageSummary extends StatelessWidget {
  const PlanUsageSummary({
    super.key,
    required this.usage,
    required this.subscriptionInfo,
  });

  final WorkspaceUsagePB usage;
  final WorkspaceSubscriptionInfoPB subscriptionInfo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle(context),
        const VSpace(16),
        _buildUsageBoxes(),
        const VSpace(16),
        _buildToggles(context),
      ],
    );
  }

  Widget _buildTitle(BuildContext context) {
    return FlowyText.semibold(
      LocaleKeys.settings_planPage_planUsage_title.tr(),
      maxLines: 2,
      fontSize: 16,
      overflow: TextOverflow.ellipsis,
      color: AFThemeExtension.of(context).secondaryTextColor,
    );
  }

  Widget _buildUsageBoxes() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: UsageBox(
            title: LocaleKeys.settings_planPage_planUsage_storageLabel.tr(),
            unlimitedLabel: LocaleKeys
                .settings_planPage_planUsage_unlimitedStorageLabel
                .tr(),
            unlimited: usage.storageBytesUnlimited,
            label: LocaleKeys.settings_planPage_planUsage_storageUsage.tr(
              args: [
                usage.currentBlobInGb,
                usage.totalBlobInGb,
              ],
            ),
            value: usage.storageBytes.toInt() / usage.storageBytesLimit.toInt(),
          ),
        ),
        Expanded(
          child: UsageBox(
            title: LocaleKeys.settings_planPage_planUsage_aiResponseLabel.tr(),
            label: LocaleKeys.settings_planPage_planUsage_aiResponseUsage.tr(
              args: [
                usage.aiResponsesCount.toString(),
                usage.aiResponsesCountLimit.toString(),
              ],
            ),
            unlimitedLabel:
                LocaleKeys.settings_planPage_planUsage_unlimitedAILabel.tr(),
            unlimited: usage.aiResponsesUnlimited,
            value: usage.aiResponsesCount.toInt() /
                usage.aiResponsesCountLimit.toInt(),
          ),
        ),
      ],
    );
  }

  Widget _buildToggles(BuildContext context) {
    return SeparatedColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      separatorBuilder: () => const VSpace(4),
      children: [
        if (subscriptionInfo.plan == SubscriptionPlanPB.Free)
          ToggleMore(
            value: false,
            label: LocaleKeys.settings_planPage_planUsage_memberProToggle.tr(),
            badgeLabel: LocaleKeys.settings_planPage_planUsage_proBadge.tr(),
            onTap: () async {
              context.read<SettingsPlanBloc>().add(
                    const SettingsPlanEvent.addSubscription(
                      SubscriptionPlanPB.Pro,
                    ),
                  );
              await Future.delayed(const Duration(seconds: 2));
            },
          ),
        if (!subscriptionInfo.hasAIMax && !usage.aiResponsesUnlimited)
          ToggleMore(
            value: false,
            label: LocaleKeys.settings_planPage_planUsage_aiMaxToggle.tr(),
            badgeLabel: LocaleKeys.settings_planPage_planUsage_proBadge.tr(),
            onTap: () async {
              context.read<SettingsPlanBloc>().add(
                    const SettingsPlanEvent.addSubscription(
                      SubscriptionPlanPB.AiMax,
                    ),
                  );
              await Future.delayed(const Duration(seconds: 2));
            },
          ),
      ],
    );
  }
}
