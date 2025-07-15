import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/shared/flowy_error_page.dart';
import 'package:appflowy/shared/loading.dart';
import 'package:appflowy/workspace/application/settings/plan/settings_plan_bloc.dart';
import 'package:appflowy/workspace/application/settings/plan/settings_person_plan_bloc.dart';
import 'package:appflowy/workspace/presentation/settings/pages/settings_plan_view/widgets/widgets.dart';
import 'package:appflowy/workspace/presentation/settings/shared/settings_body.dart';
import 'package:appflowy_backend/protobuf/flowy-user/user_profile.pb.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/theme_extension.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingsPlanView extends StatefulWidget {
  const SettingsPlanView({
    super.key,
    required this.workspaceId,
    required this.user,
  });

  final String workspaceId;
  final UserProfilePB user;

  @override
  State<SettingsPlanView> createState() => _SettingsPlanViewState();
}

class _SettingsPlanViewState extends State<SettingsPlanView> {
  Loading? loadingIndicator;

  @override
  void dispose() {
    loadingIndicator?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SettingsPlanBloc>(
          create: (context) => SettingsPlanBloc(
            workspaceId: widget.workspaceId,
            userId: widget.user.id,
          )..add(const SettingsPlanEvent.started()),
        ),
        BlocProvider<SettingsPersonPlanBloc>(
          create: (context) => SettingsPersonPlanBloc(
            userId: widget.user.id,
          )..add(const SettingsPersonPlanEvent.started()),
        ),
      ],
      child: BlocListener<SettingsPlanBloc, SettingsPlanState>(
        listenWhen: (previous, current) =>
            previous.mapOrNull(ready: (s) => s.downgradeProcessing) !=
            current.mapOrNull(ready: (s) => s.downgradeProcessing),
        listener: (context, state) {
          if (state.mapOrNull(ready: (s) => s.downgradeProcessing) == true) {
            loadingIndicator = Loading(context)..start();
          } else {
            loadingIndicator?.stop();
            loadingIndicator = null;
          }
        },
        child: BlocBuilder<SettingsPlanBloc, SettingsPlanState>(
          builder: (context, workspaceState) =>
              BlocBuilder<SettingsPersonPlanBloc, SettingsPersonPlanState>(
            builder: (context, personalState) =>
                _buildContent(context, workspaceState, personalState),
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalStateWidget(SettingsPersonPlanState personalState) {
    return personalState.map(
      initial: (_) => const _LoadingAddOnBox(),
      loading: (_) => const _LoadingAddOnBox(),
      error: (_) => const SizedBox.shrink(),
      ready: (readyState) => VaultWorkspaceAddOn(
        subscriptions: readyState.subscriptionInfo,
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    SettingsPlanState workspaceState,
    SettingsPersonPlanState personalState,
  ) {
    return workspaceState.map(
      initial: (_) => const SizedBox.shrink(),
      loading: (_) => const Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator.adaptive(strokeWidth: 3),
        ),
      ),
      error: (state) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: AppFlowyErrorPage(
              error: state.error,
            ),
          ),
        );
      },
      ready: (state) {
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            SettingsBody(
              autoSeparate: false,
              title: LocaleKeys.settings_planPage_title.tr(),
              children: [
                PlanUsageSummary(
                  usage: state.workspaceUsage,
                  subscriptionInfo: state.subscriptionInfo,
                ),
                const VSpace(16),
                CurrentPlanBox(subscriptionInfo: state.subscriptionInfo),
                const VSpace(16),
                _SectionTitle(
                  title:
                      LocaleKeys.settings_planPage_planUsage_addons_title.tr(),
                  tooltip: LocaleKeys.settings_planPage_planUsage_addons_tooltip
                      .tr(),
                ),
                const VSpace(8),
                AIMaxAddOn(
                  subscriptionInfo: state.subscriptionInfo,
                ),
                const VSpace(16),
                _SectionTitle(
                  title: LocaleKeys
                      .settings_planPage_planUsage_accountAddons_title
                      .tr(),
                  tooltip: LocaleKeys
                      .settings_planPage_planUsage_accountAddons_tooltip
                      .tr(),
                ),
                const VSpace(8),
                _buildPersonalStateWidget(personalState),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.tooltip,
  });

  final String title;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return Row(
      children: [
        FlowyText(
          title,
          fontSize: 18,
          color: AFThemeExtension.of(context).strongText,
          fontWeight: FontWeight.w600,
        ),
        const HSpace(4),
        if (tooltip != null)
          FlowyTooltip(
            message: tooltip!,
            maxWidth: 600,
            child: AFGhostButton.normal(
              onTap: () {},
              padding: EdgeInsets.zero,
              builder: (context, isHovering, disabled) => FlowySvg(
                FlowySvgs.ai_explain_m,
                size: const Size.square(20),
                color: theme.iconColorScheme.secondary,
              ),
            ),
          ),
      ],
    );
  }
}

class _LoadingAddOnBox extends StatelessWidget {
  const _LoadingAddOnBox();

  static const _loadingIndicatorSize = 24.0;
  static const _borderRadius = 16.0;
  static const _horizontalPadding = 16.0;
  static const _verticalPadding = 12.0;
  static const _strokeWidth = 3.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: _horizontalPadding,
        vertical: _verticalPadding,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.dividerColor,
        ),
        color: Color(0xFFF7F8FC).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(_borderRadius),
      ),
      child: const Center(
        child: SizedBox.square(
          dimension: _loadingIndicatorSize,
          child: CircularProgressIndicator.adaptive(strokeWidth: _strokeWidth),
        ),
      ),
    );
  }
}
