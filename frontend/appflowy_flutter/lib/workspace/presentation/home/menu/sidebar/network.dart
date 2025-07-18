import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/util/theme_extension.dart';
import 'package:appflowy/workspace/application/sidebar/network_indicator_bloc.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/protobuf/flowy-user/workspace.pb.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/theme_extension.dart';
import 'package:flowy_infra_ui/style_widget/button.dart';
import 'package:flowy_infra_ui/style_widget/text.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:universal_platform/universal_platform.dart';

class WebSocketIndicator extends StatefulWidget {
  const WebSocketIndicator({super.key, required this.workspaceId});

  final String workspaceId;

  static const double _indicatorHeight = 42.0;

  @override
  State<WebSocketIndicator> createState() => _WebSocketIndicatorState();
}

class _WebSocketIndicatorState extends State<WebSocketIndicator>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      UserEventStartWSConnectIfNeed().send();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          NetworkIndicatorBloc(workspaceId: widget.workspaceId),
      child: BlocBuilder<NetworkIndicatorBloc, NetworkIndicatorState>(
        buildWhen: (previous, current) =>
            previous.connectState != current.connectState,
        builder: (context, state) {
          final connectState = state.connectState;
          if (connectState == null) {
            return const SizedBox.shrink();
          }

          return _buildStateIndicator(connectState, context);
        },
      ),
    );
  }

  Widget _buildStateIndicator(ConnectStatePB state, BuildContext context) {
    switch (state) {
      case ConnectStatePB.WSConnecting:
        return _buildConnectingIndicator(context);
      case ConnectStatePB.WSConnected:
        return const SizedBox.shrink();
      case ConnectStatePB.WSDisconnected:
        if (UniversalPlatform.isMobile) {
          return _buildMobileDisconnectedIndicator(context);
        } else {
          return _buildDisconnectedIndicator(context);
        }
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildConnectingIndicator(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    final backgroundColor = Theme.of(context).isLightMode
        ? Color(0xffF8FAFF)
        : theme.surfaceColorScheme.layer01;
    return Container(
      color: backgroundColor,
      height: WebSocketIndicator._indicatorHeight,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.xxl,
          vertical: theme.spacing.l,
        ),
        child: Row(
          children: [
            SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator.adaptive(),
            ),
            HSpace(8),
            FlowyText.regular(
              LocaleKeys.network_connecting.tr(),
              fontSize: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisconnectedIndicator(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    final backgroundColor = Theme.of(context).isLightMode
        ? Color(0xffF8FAFF)
        : theme.surfaceColorScheme.layer01;

    return Container(
      color: backgroundColor,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.xxl,
          vertical: theme.spacing.l,
        ),
        child: Row(
          children: [
            const FlowySvg(FlowySvgs.lost_connection_m),
            const HSpace(8),
            FlowyText.regular(
              LocaleKeys.network_lost_connnection.tr(),
              fontSize: 14,
            ),
            HSpace(theme.spacing.xl),
            _buildReconnectButton(context, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileDisconnectedIndicator(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    final backgroundColor = Theme.of(context).isLightMode
        ? Color(0xffF8FAFF)
        : theme.surfaceColorScheme.layer01;
    return Container(
      color: backgroundColor,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.xxl,
          vertical: theme.spacing.l,
        ),
        child: Row(
          children: [
            const FlowySvg(FlowySvgs.lost_connection_m),
            const HSpace(8),
            FlowyText.regular(
              LocaleKeys.network_lost_connnection_mobile.tr(),
              fontSize: 14,
            ),
            const Spacer(),
            _buildReconnectButton(context, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildReconnectButton(
    BuildContext context,
    AppFlowyThemeData theme,
  ) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: theme.borderColorScheme.primary,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: FlowyButton(
        margin: EdgeInsets.symmetric(
          vertical: theme.spacing.xs,
          horizontal: theme.spacing.l,
        ),
        useIntrinsicWidth: true,
        text: FlowyText.regular(
          LocaleKeys.network_reconnect.tr(),
          fontSize: 14,
          color: AFThemeExtension.of(context).textColor,
        ),
        onTap: () {
          context
              .read<NetworkIndicatorBloc>()
              .add(const NetworkIndicatorEvent.reconnect());
        },
      ),
    );
  }
}
