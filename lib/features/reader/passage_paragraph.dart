import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import '../../data/bible.dart';

class ParagraphGeometry {
  final ranges = <String, ({GlobalKey key, int start, int end})>{};
  String? hit(Offset point) {
    for (final entry in ranges.entries) {
      final paragraph = entry.value.key.currentContext?.findRenderObject();
      if (paragraph is! RenderParagraph || !paragraph.hasSize) continue;
      final local = paragraph.globalToLocal(point);
      for (final box in paragraph.getBoxesForSelection(TextSelection(
          baseOffset: entry.value.start, extentOffset: entry.value.end))) {
        if (box.toRect().inflate(2).contains(local)) return entry.key;
      }
    }
    return null;
  }
}

class PassageParagraph extends StatefulWidget {
  final List<BibleVerse> verses;
  final String prefix;
  final double fontSize;
  final bool redLetters;
  final Map<String, GlobalKey> anchors;
  final ParagraphGeometry geometry;
  final Color? Function(String) background;
  final ValueChanged<String> onVerse;
  final List<InlineSpan> Function(String, BibleVerse) indicators;
  const PassageParagraph(
      {super.key,
      required this.verses,
      required this.prefix,
      required this.fontSize,
      required this.redLetters,
      required this.anchors,
      required this.geometry,
      required this.background,
      required this.onVerse,
      required this.indicators});
  @override
  State<PassageParagraph> createState() => _PassageParagraphState();
}

class _PassageParagraphState extends State<PassageParagraph> {
  final renderKey = GlobalKey();
  final taps = <String, TapGestureRecognizer>{};
  @override
  void dispose() {
    for (final tap in taps.values) {
      tap.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final red = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xffffa59b)
        : const Color(0xffa52c30);
    final spans = <InlineSpan>[];
    var offset = 0;
    for (final verse in widget.verses) {
      final reference = '${widget.prefix}.${verse.number}';
      final tap = taps.putIfAbsent(reference, TapGestureRecognizer.new)
        ..onTap = () => widget.onVerse(reference);
      final contents = <InlineSpan>[
        TextSpan(
            recognizer: tap,
            text: '${verse.number} ',
            style: TextStyle(fontSize: 12, color: colors.primary)),
        if (verse.readingFormat case final format?)
          for (final segment in format.segments)
            TextSpan(
                recognizer: tap,
                text: segment.text,
                style: TextStyle(
                    fontStyle: segment.italic ? FontStyle.italic : null,
                    color:
                        widget.redLetters && segment.wordsOfJesus ? red : null))
        else
          TextSpan(recognizer: tap, text: verse.text),
        ...widget.indicators(reference, verse),
        const TextSpan(text: ' '),
      ];
      final span = TextSpan(
          recognizer: tap,
          style: TextStyle(backgroundColor: widget.background(reference)),
          children: contents);
      final length = span.toPlainText().length;
      widget.anchors[reference] = renderKey;
      widget.geometry.ranges[reference] =
          (key: renderKey, start: offset, end: offset + length);
      spans.add(span);
      offset += length;
    }
    return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: RichText(
            key: renderKey,
            textScaler: MediaQuery.textScalerOf(context),
            text: TextSpan(
                style: TextStyle(
                    fontFamily: 'SourceSerif4',
                    fontSize: widget.fontSize,
                    height: 1.75,
                    color: colors.onSurface),
                children: spans)));
  }
}
