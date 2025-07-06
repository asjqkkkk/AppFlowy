import 'package:appflowy/workspace/application/settings/billing/settings_workspace_sub_billing_bloc.dart';
import 'package:appflowy/workspace/presentation/settings/shared/settings_category.dart';
import 'package:appflowy/workspace/presentation/settings/shared/single_setting_action.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../../generated/locale_keys.g.dart';
import 'constants.dart';

/// Widget that displays payment method details and allows users to manage them
class PaymentDetailsSection extends StatelessWidget {
  const PaymentDetailsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsCategory(
      title: LocaleKeys.settings_billingPage_paymentDetails_title.tr(),
      children: [
        SingleSettingAction(
          onPressed: () => _openCustomerPortal(context),
          label:
              LocaleKeys.settings_billingPage_paymentDetails_methodLabel.tr(),
          fontWeight: FontWeight.w500,
          buttonLabel: LocaleKeys
              .settings_billingPage_paymentDetails_methodButtonLabel
              .tr(),
          minWidth: kBillingButtonsMinWidth,
        ),
      ],
    );
  }

  void _openCustomerPortal(BuildContext context) {
    context.read<SettingsWorkspaceSubscriptionBillingBloc>().add(
          const SettingsWorkspaceSubscriptionBillingEvent.openCustomerPortal(),
        );
  }
}
