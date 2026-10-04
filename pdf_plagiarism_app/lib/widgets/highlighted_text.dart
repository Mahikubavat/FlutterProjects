import 'package:flutter/material.dart';

import '../models/match_range.dart';
import '../theme/app_theme.dart';

/// Renders [text] with every character range in [ranges] highlighted -
/// this is how "highlight copied content" is implemented: the
/// similarity service returns exact character offsets of matched
/// phrases, and this widget just paints them.
class HighlightedText extends StatelessWidget {
  final String text;
  final List<MatchRange> ranges;
  final Color highlightColor;

  const HighlightedText({
    super.key,
    required this.text,
    required this.ranges,
    this.highlightColor = AppColors.match,
  });

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final sorted = [...ranges]..sort((a, b) => a.start.compareTo(b.start));

    int cursor = 0;
    for (final r in sorted) {
      final start = r.start.clamp(0, text.length);
      final end = r.end.clamp(0, text.length);
      if (start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, start)));
      }
      if (start < end) {
        spans.add(TextSpan(
          text: text.substring(start, end),
          style: TextStyle(
            backgroundColor: highlightColor,
            fontWeight: FontWeight.w600,
          ),
        ));
      }
      cursor = end > cursor ? end : cursor;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return SelectableText.rich(
      TextSpan(
        style: const TextStyle(color: AppColors.text, height: 1.6, fontSize: 14.5),
        children: spans,
      ),
    );
  }
}
