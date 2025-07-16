import 'package:flutter/material.dart';

const _tooltipWaitDuration = Duration(milliseconds: 300);

class FlowyTooltip extends StatelessWidget {
  const FlowyTooltip({
    super.key,
    this.message,
    this.richMessage,
    this.preferBelow,
    this.margin,
    this.verticalOffset,
    this.padding,
    this.maxWidth,
    this.child,
  });

  final String? message;
  final InlineSpan? richMessage;
  final bool? preferBelow;
  final EdgeInsetsGeometry? margin;
  final Widget? child;
  final double? verticalOffset;
  final EdgeInsets? padding;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    if (message == null && richMessage == null) {
      return child ?? const SizedBox.shrink();
    }

    final TextStyle? textStyle;
    final String? tooltipMessage;
    final InlineSpan? tooltipRichMessage;

    if (maxWidth == null) {
      textStyle = message == null ? null : context.tooltipTextStyle();
      tooltipMessage = message;
      tooltipRichMessage = richMessage;
    } else {
      // TODO: replace implementation with https://github.com/flutter/flutter/pull/163314 to avoid regressions in other tooltips
      textStyle = null;
      tooltipMessage = null;
      tooltipRichMessage = WidgetSpan(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth!),
          child: richMessage == null
              ? Text(
                  message!,
                  style: context.tooltipTextStyle(),
                  softWrap: true,
                )
              : Text.rich(
                  richMessage!,
                  style: context.tooltipTextStyle(),
                ),
        ),
      );
    }

    return Tooltip(
      margin: margin,
      verticalOffset: verticalOffset ?? 16.0,
      padding: padding ??
          const EdgeInsets.symmetric(
            horizontal: 12.0,
            vertical: 8.0,
          ),
      decoration: BoxDecoration(
        color: context.tooltipBackgroundColor(),
        borderRadius: BorderRadius.circular(10.0),
      ),
      waitDuration: _tooltipWaitDuration,
      message: tooltipMessage,
      richMessage: tooltipRichMessage,
      textStyle: textStyle,
      preferBelow: preferBelow,
      child: child,
    );
  }
}

class ManualTooltip extends StatefulWidget {
  const ManualTooltip({
    super.key,
    this.message,
    this.richMessage,
    this.preferBelow,
    this.margin,
    this.verticalOffset,
    this.padding,
    this.showAutomaticlly = false,
    this.child,
  });

  final String? message;
  final InlineSpan? richMessage;
  final bool? preferBelow;
  final EdgeInsetsGeometry? margin;
  final Widget? child;
  final double? verticalOffset;
  final EdgeInsets? padding;
  final bool showAutomaticlly;

  @override
  State<ManualTooltip> createState() => _ManualTooltipState();
}

class _ManualTooltipState extends State<ManualTooltip> {
  final key = GlobalKey<TooltipState>();

  @override
  void initState() {
    if (widget.showAutomaticlly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) key.currentState?.ensureTooltipVisible();
      });
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      key: key,
      margin: widget.margin,
      verticalOffset: widget.verticalOffset ?? 16.0,
      triggerMode: widget.showAutomaticlly ? TooltipTriggerMode.manual : null,
      padding: widget.padding ??
          const EdgeInsets.symmetric(
            horizontal: 12.0,
            vertical: 8.0,
          ),
      decoration: BoxDecoration(
        color: context.tooltipBackgroundColor(),
        borderRadius: BorderRadius.circular(10.0),
      ),
      waitDuration: _tooltipWaitDuration,
      message: widget.message,
      textStyle: widget.message != null ? context.tooltipTextStyle() : null,
      richMessage: widget.richMessage,
      preferBelow: widget.preferBelow,
      child: widget.child,
    );
  }
}

extension FlowyToolTipExtension on BuildContext {
  double tooltipFontSize() => 14.0;

  double tooltipHeight({double? fontSize}) =>
      20.0 / (fontSize ?? tooltipFontSize());

  Color tooltipFontColor() => Theme.of(this).brightness == Brightness.light
      ? Colors.white
      : Colors.black;

  TextStyle? tooltipTextStyle({Color? fontColor, double? fontSize}) {
    return Theme.of(this).textTheme.bodyMedium?.copyWith(
          color: fontColor ?? tooltipFontColor(),
          fontSize: fontSize ?? tooltipFontSize(),
          fontWeight: FontWeight.w400,
          height: tooltipHeight(fontSize: fontSize),
          leadingDistribution: TextLeadingDistribution.even,
        );
  }

  TextStyle? tooltipHintTextStyle({double? fontSize}) => tooltipTextStyle(
        fontColor: tooltipFontColor().withValues(alpha: 0.7),
        fontSize: fontSize,
      );

  Color tooltipBackgroundColor() =>
      Theme.of(this).brightness == Brightness.light
          ? const Color(0xFF1D2129)
          : const Color(0xE5E5E5E5);
}
