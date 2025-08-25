import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flutter/material.dart';
import 'package:markdown_widget/config/all.dart';
import 'package:markdown_widget/widget/all.dart';
import 'package:markdown/markdown.dart' as m;

class PreviewDescriptionMarkdownRender extends StatelessWidget {
  const PreviewDescriptionMarkdownRender({
    super.key,
    required this.description,
    this.textAlign,
    this.textStyle,
  });
  final String description;
  final TextAlign? textAlign;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context),
        style = textStyle ??
            theme.textStyle.caption
                .standard(color: theme.textColorScheme.primary);
    final mdConfig = MarkdownConfig(configs: [PConfig(textStyle: style)]);
    final m.Document document = m.Document(
      encodeHtml: false,
      withDefaultBlockSyntaxes: false,
      inlineSyntaxes: [
        m.StrikethroughSyntax(),
      ],
    );
    final regExp = WidgetVisitor.defaultSplitRegExp;
    final List<String> lines = description.split(regExp);
    final List<m.Node> nodes = document.parseLines(lines);
    final visitor = WidgetVisitor(
      config: mdConfig,
      splitRegExp: regExp,
    );
    final spans = visitor.visit(nodes);
    final List<InlineSpan> inlineSpans = [];
    for (final span in spans) {
      inlineSpans.add(span.build());
    }
    return Text.rich(TextSpan(children: inlineSpans), textAlign: textAlign);
  }
}
