import 'package:flutter/material.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';

/// Text with every occurrence of [query] emphasised.
///
/// Used in the picker sheets so a search result shows *why* it matched — with
/// a list of similarly-named banks, the difference is otherwise easy to miss.
class HighlightedText extends StatelessWidget {
  const HighlightedText({
    super.key,
    required this.text,
    required this.query,
    this.style,
    this.highlightStyle,
    this.maxLines,
    this.overflow,
  });

  final String text;

  /// Matched case-insensitively. An empty query renders [text] unchanged.
  final String query;

  final TextStyle? style;
  final TextStyle? highlightStyle;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? Theme.of(context).textTheme.titleMedium;
    final trimmedQuery = query.trim();

    if (trimmedQuery.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final emphasis = highlightStyle ??
        baseStyle?.copyWith(
          color: context.scheme.primary,
          fontWeight: FontWeight.w700,
          backgroundColor: context.scheme.primary.withValues(alpha: 0.12),
        );

    final spans = <TextSpan>[];
    final haystack = text.toLowerCase();
    final needle = trimmedQuery.toLowerCase();
    var cursor = 0;

    while (cursor < text.length) {
      final matchStart = haystack.indexOf(needle, cursor);
      if (matchStart < 0) {
        spans.add(TextSpan(text: text.substring(cursor)));
        break;
      }
      if (matchStart > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, matchStart)));
      }
      final matchEnd = matchStart + needle.length;
      spans.add(TextSpan(
        text: text.substring(matchStart, matchEnd),
        style: emphasis,
      ));
      cursor = matchEnd;
    }

    return Text.rich(
      TextSpan(style: baseStyle, children: spans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      // The spans carry the styling; the plain string is what assistive tech
      // should read.
      semanticsLabel: text,
    );
  }
}
