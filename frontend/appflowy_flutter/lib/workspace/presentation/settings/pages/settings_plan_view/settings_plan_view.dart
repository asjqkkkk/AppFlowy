import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/shared/flowy_error_page.dart';
import 'package:appflowy/shared/loading.dart';
import 'package:appflowy/workspace/application/settings/plan/settings_plan_bloc.dart';
import 'package:appflowy/workspace/application/settings/plan/settings_person_plan_bloc.dart';
import 'package:appflowy/workspace/presentation/settings/pages/settings_plan_view/widgets/widgets.dart';
import 'package:appflowy/workspace/presentation/settings/shared/settings_body.dart';
import 'package:appflowy_backend/protobuf/flowy-user/user_profile.pb.dart';
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
          builder: (context, workspaceState) {
            return BlocBuilder<SettingsPersonPlanBloc, SettingsPersonPlanState>(
              builder: (context, personalState) {
                return _buildContent(context, workspaceState, personalState);
              },
            );
          },
        ),
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
        child: SizedBox(
          height: 24,
          width: 24,
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
      ready: (state) => SettingsBody(
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
          FlowyText(
            LocaleKeys.settings_planPage_planUsage_addons_title.tr(),
            fontSize: 18,
            color: AFThemeExtension.of(context).strongText,
            fontWeight: FontWeight.w600,
          ),
          const VSpace(8),
          IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: AIMaxAddOn(
                    subscriptionInfo: state.subscriptionInfo,
                  ),
                ),
                const HSpace(8),
                Flexible(
                  child: personalState.map(
                    initial: (_) => const _LoadingAddOnBox(),
                    loading: (_) => const _LoadingAddOnBox(),
                    error: (_) => const SizedBox.shrink(),
                    ready: (readyState) => VaultWorkspaceAddOn(
                      subscriptions: readyState.subscriptionInfo,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingAddOnBox extends StatelessWidget {
  const _LoadingAddOnBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color(0xFFBDBDBD),
        ),
        color: const Color(0xFFF7F8FC).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator.adaptive(strokeWidth: 3),
        ),
      ),
    );
  }
}
