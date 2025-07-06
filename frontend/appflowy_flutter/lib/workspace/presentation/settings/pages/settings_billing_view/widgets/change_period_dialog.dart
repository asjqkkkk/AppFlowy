import 'package:appflowy/workspace/application/settings/plan/workspace_subscription_ext.dart';
import 'package:appflowy/workspace/presentation/settings/shared/settings_alert_dialog.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/style_widget/text.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';

import '../../../../../../generated/locale_keys.g.dart';

/// Dialog for changing the billing period of a subscription
class ChangePeriodDialog extends StatefulWidget {
  const ChangePeriodDialog({
    super.key,
    required this.currentPlan,
    required this.currentInterval,
    required this.onConfirm,
  });

  final SubscriptionPlanPB currentPlan;
  final RecurringIntervalPB currentInterval;
  final Function(RecurringIntervalPB) onConfirm;

  @override
  State<ChangePeriodDialog> createState() => _ChangePeriodDialogState();
}

class _ChangePeriodDialogState extends State<ChangePeriodDialog> {
  RecurringIntervalPB? _selectedInterval;
  final ValueNotifier<bool> _enableConfirmNotifier = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _selectedInterval = widget.currentInterval;
  }

  @override
  void dispose() {
    _enableConfirmNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsAlertDialog(
      title: LocaleKeys.settings_billingPage_changePeriod.tr(),
      enableConfirmNotifier: _enableConfirmNotifier,
      children: [
        _ChangePeriodContent(
          plan: widget.currentPlan,
          selectedInterval: widget.currentInterval,
          onSelected: _handleIntervalSelection,
        ),
      ],
      confirm: () {
        if (_selectedInterval != null) {
          widget.onConfirm(_selectedInterval!);
        }
        Navigator.of(context).pop();
      },
    );
  }

  void _handleIntervalSelection(RecurringIntervalPB interval) {
    setState(() {
      _selectedInterval = interval;
      _enableConfirmNotifier.value = interval != widget.currentInterval;
    });
  }
}

/// The content of the change period dialog
class _ChangePeriodContent extends StatefulWidget {
  const _ChangePeriodContent({
    required this.plan,
    required this.selectedInterval,
    required this.onSelected,
  });

  final SubscriptionPlanPB plan;
  final RecurringIntervalPB selectedInterval;
  final Function(RecurringIntervalPB interval) onSelected;

  @override
  State<_ChangePeriodContent> createState() => _ChangePeriodContentState();
}

class _ChangePeriodContentState extends State<_ChangePeriodContent> {
  RecurringIntervalPB? _selectedInterval;

  @override
  void initState() {
    super.initState();
    _selectedInterval = widget.selectedInterval;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PeriodOption(
          price: widget.plan.priceMonthBilling,
          interval: RecurringIntervalPB.Month,
          isSelected: _selectedInterval == RecurringIntervalPB.Month,
          isCurrent: widget.selectedInterval == RecurringIntervalPB.Month,
          onSelected: () => _selectInterval(RecurringIntervalPB.Month),
        ),
        const VSpace(16),
        _PeriodOption(
          price: widget.plan.priceAnnualBilling,
          interval: RecurringIntervalPB.Year,
          isSelected: _selectedInterval == RecurringIntervalPB.Year,
          isCurrent: widget.selectedInterval == RecurringIntervalPB.Year,
          onSelected: () => _selectInterval(RecurringIntervalPB.Year),
        ),
      ],
    );
  }

  void _selectInterval(RecurringIntervalPB interval) {
    widget.onSelected(interval);
    setState(() => _selectedInterval = interval);
  }
}

/// Individual period option in the change period dialog
class _PeriodOption extends StatelessWidget {
  const _PeriodOption({
    required this.price,
    required this.interval,
    required this.onSelected,
    required this.isSelected,
    required this.isCurrent,
  });

  final String price;
  final RecurringIntervalPB interval;
  final VoidCallback onSelected;
  final bool isSelected;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isCurrent && !isSelected ? 0.7 : 1,
      child: GestureDetector(
        onTap: isCurrent ? null : onSelected,
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).dividerColor,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildPeriodInfo(context),
            const Spacer(),
            if (!isCurrent && !isSelected || isSelected)
              _buildRadioButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FlowyText(
              interval.label,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            if (isCurrent) ...[
              const HSpace(8),
              _buildCurrentBadge(context),
            ],
          ],
        ),
        const VSpace(8),
        FlowyText(
          price,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        const VSpace(4),
        FlowyText(
          interval.priceInfo,
          fontWeight: FontWeight.w400,
          fontSize: 12,
        ),
      ],
    );
  }

  Widget _buildCurrentBadge(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: FlowyText(
          LocaleKeys.settings_billingPage_currentPeriodBadge.tr(),
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildRadioButton(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          width: 1.5,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).dividerColor,
        ),
      ),
      child: SizedBox(
        height: 22,
        width: 22,
        child: Center(
          child: SizedBox(
            width: 10,
            height: 10,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
