import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

enum _MathSegmentType { text, inlineMath, blockMath }

class _MathSegment {
  final _MathSegmentType type;
  final String content;

  _MathSegment(this.type, this.content);
}

/// A high-performance parsed segment cache to prevent regex parsing overhead on re-renders
final Map<String, List<_MathSegment>> _segmentCache = {};

List<_MathSegment> _parseSegments(String input) {
  if (_segmentCache.containsKey(input)) {
    return _segmentCache[input]!;
  }

  final segments = <_MathSegment>[];
  // Pattern to extract block math ($$ or \[...\]) and inline math ($ or \(...\))
  final pattern = RegExp(
    r'(?:\$\$(.*?)\$\$)|(?:\$(.*?)\$)|(?:\\\[(.*?)\\\])|(?:\\\((.*?)\\\))',
    dotAll: true,
  );

  int lastIndex = 0;
  for (final match in pattern.allMatches(input)) {
    if (match.start > lastIndex) {
      segments.add(_MathSegment(
        _MathSegmentType.text,
        input.substring(lastIndex, match.start),
      ));
    }

    if (match.group(1) != null) {
      segments.add(_MathSegment(_MathSegmentType.blockMath, match.group(1)!));
    } else if (match.group(2) != null) {
      segments.add(_MathSegment(_MathSegmentType.inlineMath, match.group(2)!));
    } else if (match.group(3) != null) {
      segments.add(_MathSegment(_MathSegmentType.blockMath, match.group(3)!));
    } else if (match.group(4) != null) {
      segments.add(_MathSegment(_MathSegmentType.inlineMath, match.group(4)!));
    }

    lastIndex = match.end;
  }

  if (lastIndex < input.length) {
    segments.add(_MathSegment(
      _MathSegmentType.text,
      input.substring(lastIndex),
    ));
  }

  _segmentCache[input] = segments;
  return segments;
}

/// LaTeX math rendering widget using high-performance native canvas calls via flutter_math_fork
class LaTeXWidget extends StatelessWidget {
  final String text;
  final double? height;
  final TextAlign? textAlign;
  final Color? color;

  const LaTeXWidget({
    super.key,
    required this.text,
    this.height,
    this.textAlign,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final segments = _parseSegments(text);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = color ?? (isDark ? const Color(0xFFDAE2FD) : const Color(0xFF1A1A2E));

    final children = <Widget>[];
    final inlineSpans = <InlineSpan>[];

    void flushInlineSpans() {
      if (inlineSpans.isNotEmpty) {
        children.add(
          RichText(
            textAlign: textAlign ?? TextAlign.start,
            text: TextSpan(
              style: TextStyle(
                fontSize: 15,
                color: defaultColor,
                height: 1.4,
              ),
              children: List.from(inlineSpans),
            ),
          ),
        );
        inlineSpans.clear();
      }
    }

    for (final seg in segments) {
      if (seg.type == _MathSegmentType.text) {
        inlineSpans.add(TextSpan(text: seg.content));
      } else if (seg.type == _MathSegmentType.inlineMath) {
        inlineSpans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Math.tex(
                seg.content.trim(),
                mathStyle: MathStyle.text,
                textStyle: TextStyle(
                  fontSize: 15,
                  color: defaultColor,
                ),
                onErrorFallback: (err) {
                  return Text(
                    '\$${seg.content}\$',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  );
                },
              ),
            ),
          ),
        );
      } else if (seg.type == _MathSegmentType.blockMath) {
        flushInlineSpans();
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Math.tex(
                  seg.content.trim(),
                  mathStyle: MathStyle.display,
                  textStyle: TextStyle(
                    fontSize: 16,
                    color: defaultColor,
                  ),
                  onErrorFallback: (err) {
                    return Text(
                      '\$\$${seg.content}\$\$',
                      style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      }
    }

    flushInlineSpans();

    final mainColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );

    if (height != null) {
      return SizedBox(
        height: height,
        child: SingleChildScrollView(child: mainColumn),
      );
    }

    return mainColumn;
  }
}

/// Inline math text — optimized wrapper for list view rendering and student option selections
class InlineMathText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color? color;

  const InlineMathText({
    super.key,
    required this.text,
    this.fontSize = 15,
    this.color,
  });

  bool get _hasMath =>
      text.contains(r'$') ||
      text.contains(r'\(') ||
      text.contains(r'\[') ||
      text.contains('\\');

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ??
        (Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFDAE2FD)
            : const Color(0xFF1A1A2E));

    if (_hasMath) {
      return LaTeXWidget(
        text: text,
        color: resolvedColor,
        textAlign: TextAlign.start,
      );
    }
    return Text(
      text,
      style: TextStyle(fontSize: fontSize, color: resolvedColor),
    );
  }
}
