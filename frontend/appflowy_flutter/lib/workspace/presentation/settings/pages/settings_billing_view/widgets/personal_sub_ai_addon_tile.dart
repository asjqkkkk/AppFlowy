import 'package:appflowy/util/int64_extension.dart';
import 'package:appflowy/workspace/application/settings/appearance/appearance_cubit.dart';
import 'package:appflowy/workspace/application/settings/billing/settings_personal_sub_billing_bloc.dart';
import 'package:appflowy/workspace/application/settings/date_time/date_format_ext.dart';
import 'package:appflowy/workspace/application/settings/plan/workspace_subscription_ext.dart';
import 'package:appflowy/workspace/presentation/settings/shared/single_setting_action.dart';
import 'package:appflowy/workspace/presentation/home/menu/sidebar/space/shared_widget.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../../generated/locale_keys.g.dart';
import 'constants.dart';

/// Widget that displays AI addon subscription information and management options
class PersonalSubscriptionAIAddonTile extends StatelessWidget {
  const PersonalSubscriptionAIAddonTile({
    super.key,
    required this.label,
    required this.description,
    required this.canceledDescription,
    required this.activeDescription,
    required this.plan,
  });

  final String label;
  final String description;
  final String canceledDescription;
  final String activeDescription;
  final PersonalPlanPB plan;

  @override
  Widget build(BuildContext context) {
    final dateFormat = context.read<AppearanceSettingsCubit>().state.dateFormat;

    return BlocBuilder<SettingsPersonalSubscriptionBillingBloc,
        SettingsPersonalSubscriptionBillingState>(
      builder: (context, state) {
        return state.map(
          initial: (initial) => const SizedBox.shrink(),
          loading: (loading) => _buildLoadingView(),
          error: (error) => const SizedBox.shrink(),
          ready: (ready) => SingleSettingAction(
            label: label,
            description: _getDescription(
              ready.subscriptionState,
              dateFormat,
              ready.subscription,
            ),
            buttonLabel: _getButtonLabel(ready.subscriptionState),
            fontWeight: FontWeight.w500,
            minWidth: kBillingButtonsMinWidth,
            onPressed: () =>
                _handleMainAction(context, ready.subscriptionState),
          ),
        );
      },
    );
  }

  String _getDescription(
    SubscriptionState subscriptionState,
    UserDateFormatPB dateFormat,
    PersonalSubscriptionPB subscription,
  ) {
    if (subscriptionState == SubscriptionState.cancelled) {
      final endDate = dateFormat.formatDate(
        subscription.endDate.toDateTime(),
        false,
      );
      return canceledDescription.tr(args: [endDate]);
    }

    if (subscriptionState == SubscriptionState.actived) {
      final endDate = dateFormat.formatDate(
        subscription.endDate.toDateTime(),
        false,
      );
      return activeDescription.tr(args: [endDate]);
    }

    return description.tr();
  }

  String _getButtonLabel(
    SubscriptionState subscriptionState,
  ) {
    if (subscriptionState == SubscriptionState.newSubscription) {
      return LocaleKeys.settings_billingPage_addons_addLabel.tr();
    }

    if (subscriptionState == SubscriptionState.cancelled) {
      return LocaleKeys.settings_billingPage_addons_renewLabel.tr();
    }

    return LocaleKeys.settings_billingPage_addons_removeLabel.tr();
  }

  Future<void> _handleMainAction(
    BuildContext context,
    SubscriptionState subscriptionState,
  ) async {
    if (subscriptionState == SubscriptionState.newSubscription) {
      _addAddon(context);
    } else {
      await _showRemoveAddonDialog(context);
    }
  }

  Future<void> _showRemoveAddonDialog(BuildContext context) async {
    await showConfirmDialog(
      context: context,
      style: ConfirmPopupStyle.cancelAndOk,
      title: LocaleKeys
          .settings_billingPage_addons_vaultWorkspace_unSubscribeDialogTitle
          .tr(),
      description: LocaleKeys
          .settings_billingPage_addons_vaultWorkspace_unSubscribeMessage
          .tr(),
      confirmLabel: LocaleKeys.button_confirm.tr(),
      onConfirm: (_) => _cancelAddon(context),
    );
  }

  void _addAddon(BuildContext context) {
    context
        .read<SettingsPersonalSubscriptionBillingBloc>()
        .add(SettingsPersonalSubscriptionBillingEvent.addSubscription(plan));
  }

  void _cancelAddon(BuildContext context) {
    context
        .read<SettingsPersonalSubscriptionBillingBloc>()
        .add(SettingsPersonalSubscriptionBillingEvent.cancelSubscription(plan));
  }
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
