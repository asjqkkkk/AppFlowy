import 'package:appflowy/core/helpers/url_launcher.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/workspace/application/settings/plan/settings_person_plan_bloc.dart';
import 'package:appflowy/workspace/application/settings/plan/workspace_subscription_ext.dart';
import 'package:appflowy_backend/protobuf/flowy-user/billing.pb.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/util/theme_extension.dart';
import 'package:appflowy/workspace/application/settings/plan/settings_plan_bloc.dart';
import 'package:flowy_infra/size.dart';
import 'package:flowy_infra/theme_extension.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AIMaxAddOn extends StatelessWidget {
  const AIMaxAddOn({
    super.key,
    required this.subscriptionInfo,
  });

  final WorkspaceSubscriptionInfoPB subscriptionInfo;

  @override
  Widget build(BuildContext context) {
    return AddOnBox(
      title: LocaleKeys.settings_planPage_planUsage_addons_aiMax_title.tr(),
      description:
          LocaleKeys.settings_planPage_planUsage_addons_aiMax_description.tr(),
      price: LocaleKeys.settings_planPage_planUsage_addons_aiMax_price.tr(
        args: [SubscriptionPlanPB.AiMax.priceAnnualBilling],
      ),
      priceInfo:
          LocaleKeys.settings_planPage_planUsage_addons_aiMax_priceInfo.tr(),
      recommend: '',
      buttonText: _getButtonText(),
      isActive: subscriptionInfo.hasAIMax,
      plan: SubscriptionPlanPB.AiMax,
    );
  }

  String _getButtonText() {
    return subscriptionInfo.hasAIMax
        ? LocaleKeys.settings_planPage_planUsage_addons_activeLabel.tr()
        : LocaleKeys.settings_planPage_planUsage_addons_addLabel.tr();
  }
}

class VaultWorkspaceAddOn extends StatelessWidget {
  const VaultWorkspaceAddOn({
    super.key,
    required this.subscriptions,
  });

  final PersonalSubscriptionInfoPB subscriptions;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return AddOnBox(
      title: LocaleKeys.settings_planPage_planUsage_addons_vaultWorkspace_title
          .tr(),
      titleAccessory: FlowyTooltip(
        message: LocaleKeys.workspace_learnMore.tr(),
        child: AFGhostButton.normal(
          onTap: () => afLaunchUrlString(
            "https://appflowy.com/guide/vault-workspace",
          ),
          padding: EdgeInsets.zero,
          builder: (context, isHovering, disabled) => FlowySvg(
            FlowySvgs.ai_explain_m,
            size: Size.square(20),
            color: theme.iconColorScheme.secondary,
          ),
        ),
      ),
      description: LocaleKeys
          .settings_planPage_planUsage_addons_vaultWorkspace_description
          .tr(),
      price:
          LocaleKeys.settings_planPage_planUsage_addons_vaultWorkspace_price.tr(
        args: [PersonalPlanPB.VaultWorkspace.priceAnnualBilling],
      ),
      priceInfo: LocaleKeys
          .settings_planPage_planUsage_addons_vaultWorkspace_priceInfo
          .tr(),
      recommend: '',
      buttonText: _getButtonText(),
      isActive: subscriptions.subscriptionState == SubscriptionState.actived,
      plan: PersonalPlanPB.VaultWorkspace,
    );
  }

  String _getButtonText() {
    return subscriptions.subscriptionState == SubscriptionState.actived
        ? LocaleKeys.settings_planPage_planUsage_addons_activeLabel.tr()
        : LocaleKeys.settings_planPage_planUsage_addons_addLabel.tr();
  }
}

class AddOnBox extends StatelessWidget {
  const AddOnBox({
    super.key,
    required this.title,
    this.titleAccessory,
    required this.description,
    required this.price,
    required this.priceInfo,
    required this.recommend,
    required this.buttonText,
    required this.isActive,
    required this.plan,
  });

  final String title;
  final Widget? titleAccessory;
  final String description;
  final String price;
  final String priceInfo;
  final String recommend;
  final String buttonText;
  final bool isActive;
  final Object plan;

  @override
  Widget build(BuildContext context) {
    final isLM = Theme.of(context).isLightMode;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: isActive ? const Color(0xFFBDBDBD) : const Color(0xFF9C00FB),
        ),
        color: const Color(0xFFF7F8FC).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const VSpace(10),
          _buildDescription(context),
          const VSpace(10),
          _buildPricing(context),
          const VSpace(12),
          _buildRecommendation(context),
          const VSpace(16),
          _buildActionButton(context, isLM),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return Row(
      children: [
        FlowyText.semibold(
          title,
          fontSize: 14,
          color: AFThemeExtension.of(context).strongText,
        ),
        if (titleAccessory != null) ...[
          HSpace(
            theme.spacing.xs,
          ),
          titleAccessory!,
        ],
      ],
    );
  }

  Widget _buildDescription(BuildContext context) {
    return FlowyText.regular(
      description,
      fontSize: 12,
      maxLines: 10,
      color: AFThemeExtension.of(context).secondaryTextColor,
    );
  }

  Widget _buildPricing(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FlowyText(
          price,
          fontSize: 24,
          color: AFThemeExtension.of(context).strongText,
        ),
        FlowyText(
          priceInfo,
          fontSize: 12,
          color: AFThemeExtension.of(context).strongText,
        ),
      ],
    );
  }

  Widget _buildRecommendation(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FlowyText(
            recommend,
            color: AFThemeExtension.of(context).secondaryTextColor,
            fontSize: 11,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, bool isLM) {
    return Row(
      children: [
        Expanded(
          child: FlowyTextButton(
            buttonText,
            heading: isActive ? _buildCheckIcon() : null,
            mainAxisAlignment: MainAxisAlignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            fillColor: _getButtonFillColor(isLM),
            constraints: const BoxConstraints(minWidth: 115),
            radius: Corners.s16Border,
            hoverColor: _getButtonHoverColor(isLM),
            fontColor: _getButtonFontColor(isLM),
            fontHoverColor: _getButtonFontHoverColor(),
            borderColor: _getButtonBorderColor(isLM),
            fontSize: 12,
            onPressed: isActive ? null : _handlePress(context),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckIcon() {
    return const FlowySvg(
      FlowySvgs.check_circle_outlined_s,
      color: Color(0xFF9C00FB),
    );
  }

  Color _getButtonFillColor(bool isLM) {
    if (isActive) return const Color(0xFFE8E2EE);
    return isLM ? Colors.transparent : const Color(0xFF5C3699);
  }

  Color _getButtonHoverColor(bool isLM) {
    if (isActive) return const Color(0xFFE8E2EE);
    return isLM ? const Color(0xFF5C3699) : const Color(0xFF4d3472);
  }

  Color _getButtonFontColor(bool isLM) {
    return isLM || isActive ? const Color(0xFF5C3699) : Colors.white;
  }

  Color _getButtonFontHoverColor() {
    return isActive ? const Color(0xFF5C3699) : Colors.white;
  }

  Color _getButtonBorderColor(bool isLM) {
    if (isActive) return const Color(0xFFE8E2EE);
    return isLM ? const Color(0xFF5C3699) : const Color(0xFF4d3472);
  }

  VoidCallback? _handlePress(BuildContext context) {
    return () {
      if (plan is SubscriptionPlanPB) {
        context
            .read<SettingsPlanBloc>()
            .add(SettingsPlanEvent.addSubscription(plan as SubscriptionPlanPB));
      } else if (plan is PersonalPlanPB) {
        context.read<SettingsPersonPlanBloc>().add(
              SettingsPersonPlanEvent.addSubscription(
                plan as PersonalPlanPB,
              ),
            );
      }
    };
  }
}
