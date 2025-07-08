import 'package:appflowy/shared/flowy_error_page.dart';
import 'package:appflowy/shared/loading.dart';
import 'package:appflowy/workspace/application/settings/billing/settings_workspace_sub_billing_bloc.dart';
import 'package:appflowy/workspace/application/settings/billing/settings_personal_sub_billing_bloc.dart';
import 'package:appflowy/workspace/application/settings/plan/settings_plan_bloc.dart';
import 'package:appflowy/workspace/presentation/settings/pages/settings_billing_view/widgets/workspace_sub_ai_addon_tile.dart';
import 'package:appflowy/workspace/presentation/settings/pages/settings_billing_view/widgets/billing_plan_section.dart';
import 'package:appflowy/workspace/presentation/settings/pages/settings_billing_view/widgets/payment_details_section.dart';
import 'package:appflowy/workspace/presentation/settings/pages/settings_plan_comparison_dialog.dart';
import 'package:appflowy/workspace/presentation/settings/shared/settings_body.dart';
import 'package:appflowy/workspace/presentation/settings/shared/settings_category.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:appflowy/workspace/application/settings/plan/workspace_subscription_ext.dart';
import '../../../../../generated/locale_keys.g.dart';
import 'widgets/personal_sub_ai_addon_tile.dart';

/// The main billing settings view that displays subscription information,
/// plan management, and add-on options.
class SettingsBillingView extends StatefulWidget {
  const SettingsBillingView({
    super.key,
    required this.workspaceId,
    required this.user,
  });

  final String workspaceId;
  final UserProfilePB user;

  @override
  State<SettingsBillingView> createState() => _SettingsBillingViewState();
}

class _SettingsBillingViewState extends State<SettingsBillingView> {
  Loading? _loadingIndicator;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SettingsWorkspaceSubscriptionBillingBloc>(
          create: (_) => _createWorkspaceBillingBloc(),
        ),
        BlocProvider<SettingsPersonalSubscriptionBillingBloc>(
          create: (_) => _createPersonalBillingBloc(),
        ),
      ],
      child: BlocConsumer<SettingsWorkspaceSubscriptionBillingBloc,
          SettingsWorkspaceSubscriptionBillingState>(
        listener: _handleStateChanges,
        builder: _buildContent,
      ),
    );
  }

  SettingsWorkspaceSubscriptionBillingBloc _createWorkspaceBillingBloc() {
    return SettingsWorkspaceSubscriptionBillingBloc(
      workspaceId: widget.workspaceId,
      userId: widget.user.id,
    )..add(
        const SettingsWorkspaceSubscriptionBillingEvent.started(),
      );
  }

  SettingsPersonalSubscriptionBillingBloc _createPersonalBillingBloc() {
    return SettingsPersonalSubscriptionBillingBloc(
      userId: widget.user.id,
    )..add(
        const SettingsPersonalSubscriptionBillingEvent.started(),
      );
  }

  void _handleStateChanges(
    BuildContext context,
    SettingsWorkspaceSubscriptionBillingState state,
  ) {
    final isLoading = state.mapOrNull(ready: (s) => s.isLoading) ?? false;

    if (isLoading) {
      _loadingIndicator = Loading(context)..start();
    } else {
      _loadingIndicator?.stop();
      _loadingIndicator = null;
    }
  }

  Widget _buildContent(
    BuildContext context,
    SettingsWorkspaceSubscriptionBillingState state,
  ) {
    return state.map(
      initial: (_) => const SizedBox.shrink(),
      loading: (_) => _buildLoadingView(),
      error: (errorState) => _buildErrorView(errorState),
      ready: (readyState) =>
          _buildReadyView(context, readyState.subscriptionInfo),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator.adaptive(strokeWidth: 3),
      ),
    );
  }

  Widget _buildErrorView(errorState) {
    if (errorState.error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: AppFlowyErrorPage(error: errorState.error!),
        ),
      );
    }
    return ErrorWidget.withDetails(message: 'Something went wrong!');
  }

  Widget _buildReadyView(
    BuildContext context,
    WorkspaceSubscriptionInfoPB subscriptionInfo,
  ) {
    final billingPortalEnabled = subscriptionInfo.isBillingPortalEnabled;

    return SettingsBody(
      title: LocaleKeys.settings_billingPage_title.tr(),
      children: [
        BillingPlanSection(
          subscriptionInfo: subscriptionInfo,
          onChangePlan: () => _openPricingDialog(subscriptionInfo),
          billingPortalEnabled: billingPortalEnabled,
        ),
        if (billingPortalEnabled) const PaymentDetailsSection(),
        _buildAddonsSection(subscriptionInfo),
      ],
    );
  }

  Widget _buildAddonsSection(
    WorkspaceSubscriptionInfoPB subscriptionInfo,
  ) {
    final aiMaxAddon = subscriptionInfo.addOns.firstWhere(
      (addon) => addon.type == WorkspaceAddOnPBType.AddOnAiMax,
      orElse: () => WorkspaceAddOnPB(),
    );

    return SettingsCategory(
      title: LocaleKeys.settings_billingPage_addons_title.tr(),
      children: [
        WorkspaceSubscriptionAIAddonTile(
          plan: SubscriptionPlanPB.AiMax,
          label: LocaleKeys.settings_billingPage_addons_aiMax_label.tr(),
          description: LocaleKeys.settings_billingPage_addons_aiMax_description,
          activeDescription:
              LocaleKeys.settings_billingPage_addons_aiMax_activeDescription,
          canceledDescription:
              LocaleKeys.settings_billingPage_addons_aiMax_canceledDescription,
          subscriptionInfo: aiMaxAddon.type == WorkspaceAddOnPBType.AddOnAiMax
              ? aiMaxAddon
              : null,
        ),
        const VSpace(6),
        PersonalSubscriptionAIAddonTile(
          plan: PersonalPlanPB.VaultWorkspace,
          label:
              LocaleKeys.settings_billingPage_addons_vaultWorkspace_label.tr(),
          description:
              LocaleKeys.settings_billingPage_addons_vaultWorkspace_description,
          activeDescription: LocaleKeys
              .settings_billingPage_addons_vaultWorkspace_activeDescription,
          canceledDescription: LocaleKeys
              .settings_billingPage_addons_vaultWorkspace_canceledDescription,
        ),
      ],
    );
  }

  void _openPricingDialog(WorkspaceSubscriptionInfoPB subscriptionInfo) {
    showDialog<bool?>(
      context: context,
      builder: (_) => BlocProvider<SettingsPlanBloc>(
        create: (_) => SettingsPlanBloc(
          workspaceId: widget.workspaceId,
          userId: widget.user.id,
        )..add(const SettingsPlanEvent.started()),
        child: SettingsPlanComparisonDialog(
          workspaceId: widget.workspaceId,
          subscriptionInfo: subscriptionInfo,
        ),
      ),
    ).then((didChangePlan) {
      if (didChangePlan == true && mounted) {
        context
            .read<SettingsWorkspaceSubscriptionBillingBloc>()
            .add(const SettingsWorkspaceSubscriptionBillingEvent.started());
      }
    });
  }
}
