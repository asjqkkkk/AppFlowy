import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// An animated generating indicator for an AI response
class AILoadingIndicator extends StatelessWidget {
  const AILoadingIndicator({
    super.key,
    this.texts = const [],
    this.duration = const Duration(seconds: 1),
  });

  final List<String> texts;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final slice = Duration(milliseconds: duration.inMilliseconds ~/ 5);
    return SelectionContainer.disabled(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // First text with animated dots
          if (texts.isNotEmpty)
            SeparatedRow(
              separatorBuilder: () => const HSpace(4),
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4.0),
                  child: FlowyText(
                    texts.first,
                    color: Theme.of(context).hintColor,
                  ),
                )
                    .animate()
                    .fadeIn(duration: const Duration(milliseconds: 300))
                    .slideX(
                      begin: -0.1,
                      end: 0,
                      duration: const Duration(milliseconds: 300),
                    ),
                buildDot(const Color(0xFF9327FF))
                    .animate(onPlay: (controller) => controller.repeat())
                    .slideY(duration: slice, begin: 0, end: -1)
                    .then()
                    .slideY(begin: -1, end: 1)
                    .then()
                    .slideY(begin: 1, end: 0)
                    .then()
                    .slideY(duration: slice * 2, begin: 0, end: 0),
                buildDot(const Color(0xFFFB006D))
                    .animate(onPlay: (controller) => controller.repeat())
                    .slideY(duration: slice, begin: 0, end: 0)
                    .then()
                    .slideY(begin: 0, end: -1)
                    .then()
                    .slideY(begin: -1, end: 1)
                    .then()
                    .slideY(begin: 1, end: 0)
                    .then()
                    .slideY(begin: 0, end: 0),
                buildDot(const Color(0xFFFFCE00))
                    .animate(onPlay: (controller) => controller.repeat())
                    .slideY(duration: slice * 2, begin: 0, end: 0)
                    .then()
                    .slideY(duration: slice, begin: 0, end: -1)
                    .then()
                    .slideY(begin: -1, end: 1)
                    .then()
                    .slideY(begin: 1, end: 0),
              ],
            ),
          // Remaining texts with decreasing opacity
          ...texts.skip(1).toList().asMap().entries.map((entry) {
            final index = entry.key + 1; // +1 because we skipped the first
            final text = entry.value;
            final opacity =
                1.0 - (index * 0.2); // Decrease opacity by 0.2 for each text

            return Opacity(
              opacity: opacity.clamp(0.2, 1.0),
              child: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: FlowyText(
                  text,
                  color: Theme.of(context).hintColor,
                ),
              ),
            )
                .animate()
                .fadeIn(
                  duration: const Duration(milliseconds: 300),
                  delay: Duration(milliseconds: index * 100),
                )
                .slideX(
                  begin: -0.1,
                  end: 0,
                  duration: const Duration(milliseconds: 300),
                  delay: Duration(milliseconds: index * 100),
                );
          }),
        ],
      ),
    );
  }

  Widget buildDot(Color color) {
    return SizedBox.square(
      dimension: 4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
