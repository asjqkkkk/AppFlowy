import 'package:appflowy/core/helpers/url_launcher.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/workspace/application/settings/ai/local_ai_bloc.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy/workspace/presentation/widgets/toggle/toggle.dart';
import 'package:appflowy_backend/protobuf/flowy-user/billing.pb.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fixnum/fixnum.dart';
import 'package:expandable/expandable.dart';
import 'package:flowy_infra/size.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'ollama_setting.dart';
import 'plugin_status_indicator.dart';

class LocalAISetting extends StatefulWidget {
  const LocalAISetting({super.key, required this.userId});

  final Int64 userId;

  @override
  State<LocalAISetting> createState() => _LocalAISettingState();
}

class _LocalAISettingState extends State<LocalAISetting> {
  final expandableController = ExpandableController(initialExpanded: false);

  @override
  void dispose() {
    expandableController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LocalAISettingBloc(userId: widget.userId),
      child: BlocConsumer<LocalAISettingBloc, LocalAISettingState>(
        listener: (context, state) {
          expandableController.value = state.isToggleOn;
        },
        builder: (context, state) {
          return ExpandablePanel(
            controller: expandableController,
            theme: ExpandableThemeData(
              tapBodyToCollapse: false,
              hasIcon: false,
              tapBodyToExpand: false,
              tapHeaderToExpand: false,
            ),
            header: LocalAiSettingHeader(
              isToggleOn: state.isToggleOn,
              isEnabled: state.isEnabled,
              isVault: state.isVault,
            ),
            collapsed: const SizedBox.shrink(),
            expanded: Padding(
              padding: EdgeInsets.only(top: 12),
              child: LocalAISettingPanel(),
            ),
          );
        },
      ),
    );
  }
}

class LocalAiSettingHeader extends StatelessWidget {
  const LocalAiSettingHeader({
    super.key,
    required this.isToggleOn,
    required this.isEnabled,
    required this.isVault,
  });

  final bool isToggleOn;
  final bool isEnabled;
  final bool isVault;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    if (isVault && !isEnabled) {
      return Row(
        children: [
          Expanded(
            child: FlowyText(
              LocaleKeys.settings_aiPage_keys_localAIWithoutSubscription.tr(),
              fontSize: 12,
              maxLines: 10,
              color: theme.textColorScheme.error,
            ),
          ),
          HSpace(theme.spacing.s),
          FlowyTextButton(
            LocaleKeys.settings_billingPage_addons_renewLabel.tr(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            radius: Corners.s8Border,
            fontSize: 12,
            onPressed: () {
              context.read<LocalAISettingBloc>().add(
                    const LocalAISettingEvent.addSubscription(
                      PersonalPlanPB.VaultWorkspace,
                    ),
                  );
            },
            lineHeight: 1.0,
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      LocaleKeys.settings_aiPage_keys_localAIToggleTitle.tr(),
                      style: theme.textStyle.body.enhanced(
                        color: theme.textColorScheme.primary,
                      ),
                    ),
                    HSpace(theme.spacing.s),
                    FlowyTooltip(
                      message: LocaleKeys.workspace_learnMore.tr(),
                      child: AFGhostButton.normal(
                        padding: EdgeInsets.zero,
                        builder: (context, isHovering, disabled) {
                          return FlowySvg(
                            FlowySvgs.ai_explain_m,
                            size: Size.square(20),
                          );
                        },
                        onTap: () {
                          afLaunchUrlString(
                            'https://appflowy.com/guide/appflowy-local-ai-ollama',
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const VSpace(4),
                FlowyText(
                  LocaleKeys.settings_aiPage_keys_localAIToggleSubTitle.tr(),
                  maxLines: 3,
                  fontSize: 12,
                ),
              ],
            ),
          ),
          Toggle(
            value: isToggleOn,
            onChanged: (value) {
              _onToggleChanged(value, context);
            },
          ),
        ],
      );
    }
  }

  void _onToggleChanged(bool value, BuildContext context) {
    if (value) {
      context
          .read<LocalAISettingBloc>()
          .add(const LocalAISettingEvent.toggle());
    } else {
      showConfirmDialog(
        context: context,
        title: LocaleKeys.settings_aiPage_keys_disableLocalAITitle.tr(),
        description:
            LocaleKeys.settings_aiPage_keys_disableLocalAIDescription.tr(),
        confirmLabel: LocaleKeys.button_confirm.tr(),
        onConfirm: (_) {
          context
              .read<LocalAISettingBloc>()
              .add(const LocalAISettingEvent.toggle());
        },
      );
    }
  }
}

class LocalAISettingPanel extends StatelessWidget {
  const LocalAISettingPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocalAISettingBloc, LocalAISettingState>(
      builder: (context, state) {
        return state.map(
          ready: (ready) {
            if (ready.isEnabled && ready.isToggleOn) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LocalAIStatusIndicator(),
                  const VSpace(10),
                  OllamaSettingPage(),
                ],
              );
            } else {
              return const SizedBox.shrink();
            }
          },
          loading: (_) => const SizedBox.shrink(),
        );
      },
    );
  }
}
