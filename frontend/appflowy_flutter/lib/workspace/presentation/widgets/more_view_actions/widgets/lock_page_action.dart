import 'package:appflowy/features/page_access_level/logic/page_access_level_bloc.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/widget/flowy_tooltip.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LockPageAction extends StatefulWidget {
  const LockPageAction({
    super.key,
    required this.view,
  });

  final ViewPB view;

  @override
  State<LockPageAction> createState() => _LockPageActionState();
}

class _LockPageActionState extends State<LockPageAction> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PageAccessLevelBloc, PageAccessLevelState>(
      builder: (context, state) {
        return _buildTextButton(context);
      },
    );
  }

  Widget _buildTextButton(
    BuildContext context,
  ) {
    final theme = AppFlowyTheme.of(context);

    return AFMenuItem(
      onTap: () => _toggle(context),
      title: Text(
        LocaleKeys.disclosureAction_lockPage.tr(),
        style: theme.textStyle.body.standard(
          color: theme.textColorScheme.primary,
        ),
      ),
      leading: FlowySvg(
        FlowySvgs.lock_page_s,
        size: const Size.square(16.0),
      ),
      trailing: (context, _, __) => _buildSwitch(
        context,
      ),
    );
  }

  Widget _buildSwitch(BuildContext context) {
    final lockState = context.read<PageAccessLevelBloc>().state;
    if (lockState.isLoadingLockStatus) {
      return SizedBox.shrink();
    }

    return Container(
      width: 30,
      height: 20,
      margin: const EdgeInsets.only(right: 6),
      child: FittedBox(
        fit: BoxFit.fill,
        child: CupertinoSwitch(
          value: lockState.isLocked,
          activeTrackColor: Theme.of(context).colorScheme.primary,
          onChanged: (_) => _toggle(context),
        ),
      ),
    );
  }

  Future<void> _toggle(BuildContext context) async {
    final isLocked = context.read<PageAccessLevelBloc>().state.isLocked;

    context.read<PageAccessLevelBloc>().add(
          isLocked
              ? PageAccessLevelEvent.unlock()
              : PageAccessLevelEvent.lock(),
        );

    Log.info('update page(${widget.view.id}) lock status: $isLocked');
  }
}

class LockPageButtonWrapper extends StatelessWidget {
  const LockPageButtonWrapper({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FlowyTooltip(
      message: LocaleKeys.lockPage_lockedOperationTooltip.tr(),
      child: IgnorePointer(
        child: child,
      ),
    );
  }
}
