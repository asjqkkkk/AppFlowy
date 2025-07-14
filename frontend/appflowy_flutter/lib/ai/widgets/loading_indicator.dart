import 'dart:async';

import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// An animated generating indicator for an AI response
class AILoadingIndicator extends StatefulWidget {
  const AILoadingIndicator({
    super.key,
    this.texts = const [],
    this.duration = const Duration(seconds: 1),
    this.debounceDelay = const Duration(milliseconds: 300),
  });

  final List<String> texts;
  final Duration duration;
  final Duration debounceDelay;

  @override
  State<AILoadingIndicator> createState() => _AILoadingIndicatorState();
}

class _AILoadingIndicatorState extends State<AILoadingIndicator> {
  Timer? _debounceTimer;
  List<String> _debouncedTexts = [];

  @override
  void initState() {
    super.initState();
    _debouncedTexts = widget.texts;
  }

  @override
  void didUpdateWidget(AILoadingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if texts have actually changed
    if (!_listsEqual(oldWidget.texts, widget.texts)) {
      // Cancel existing timer
      _debounceTimer?.cancel();

      // Start new debounce timer
      _debounceTimer = Timer(widget.debounceDelay, () {
        if (mounted) {
          setState(() {
            _debouncedTexts = widget.texts;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final slice = Duration(milliseconds: widget.duration.inMilliseconds ~/ 5);
    return SelectionContainer.disabled(
      child: RepaintBoundary(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // First text with animated dots
            if (_debouncedTexts.isNotEmpty)
              SeparatedRow(
                separatorBuilder: () => const HSpace(4),
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 4.0),
                    child: FlowyText(
                      _debouncedTexts.first,
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
            ..._debouncedTexts.skip(1).toList().asMap().entries.map((entry) {
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
