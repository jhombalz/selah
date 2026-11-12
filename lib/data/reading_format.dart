import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class ScriptureSegment {
  final String text;
  final bool wordsOfJesus;
  final bool italic;
  const ScriptureSegment(this.text,
      {this.wordsOfJesus = false, this.italic = false});
}

class ReadingFormat {
  final List<String> headings, notes, crossReferences;
  final List<ScriptureSegment> segments;
  final bool paragraph;
  const ReadingFormat(
      {this.headings = const [],
      this.notes = const [],
      this.crossReferences = const [],
      this.segments = const [],
      this.paragraph = false});

  static final _assets = <String, Future<Map<String, dynamic>>>{};
  static String normalized(String text) =>
      text.replaceAll('¶', '').replaceAll(RegExp(r'\s+'), ' ').trim();

  static Future<Map<String, dynamic>> load(String id) =>
      _assets.putIfAbsent(id, () async {
        if (!const {'cebocb', 'bsb', 'kjv'}.contains(id)) return {};
        final json = await compute(_decodeReadingFormat,
            await rootBundle.loadString('assets/bible/formatting/$id.json'));
        if (json['version'] != 1 || json['translation'] != id) {
          throw const FormatException('Unexpected reading format edition.');
        }
        return json['entries'] as Map<String, dynamic>;
      });

  /// Metadata is used only when its Scripture wording matches this exact verse.
  /// Older installed editions keep their original text when a source differs.
  static ReadingFormat? match(
      Map<String, dynamic> entries, String prefix, String number, String text,
      {bool bracketItalics = false}) {
    final comparison =
        bracketItalics ? text.replaceAll(RegExp(r'[\[\]]'), '') : text;
    final ends = number.split('-').map(int.parse).toList();
    final rows = <Map<String, dynamic>>[];
    final first = entries['$prefix.${ends.first}'];
    if (first is Map<String, dynamic> &&
        normalized(first['text'] as String) == normalized(comparison)) {
      rows.add(first);
    }
    if (rows.isEmpty) {
      for (int n = ends.first; n <= ends.last; n++) {
        final row = entries['$prefix.$n'];
        if (row is! Map<String, dynamic>) return null;
        rows.add(row);
      }
    }
    if (normalized(rows.map((r) => r['text'] as String).join(' ')) !=
        normalized(comparison)) {
      return null;
    }
    final segments = <ScriptureSegment>[];
    for (final row in rows) {
      if (segments.isNotEmpty) segments.add(const ScriptureSegment(' '));
      if (row['segments'] case final List<dynamic> parts) {
        for (final part in parts) {
          segments.add(part is String
              ? ScriptureSegment(part)
              : ScriptureSegment(part['text'] as String,
                  wordsOfJesus: part['jesus'] == true));
        }
      } else {
        segments.add(ScriptureSegment(row['text'] as String));
      }
    }
    return ReadingFormat(
        headings: [
          for (final row in rows)
            ...List<String>.from(row['headings'] ?? const [])
        ],
        notes: [
          for (final row in rows) ...List<String>.from(row['notes'] ?? const [])
        ],
        crossReferences: [
          for (final row in rows)
            ...List<String>.from(row['crossReferences'] ?? const [])
        ],
        segments: bracketItalics ? _kjvSegments(text, segments) : segments,
        paragraph: rows.first['paragraph'] == true);
  }

  // Square brackets in the verified KJV VPL mark translator-supplied words.
  // The display uses italics; the original text remains in search and storage.
  static List<ScriptureSegment> _kjvSegments(
      String text, List<ScriptureSegment> source) {
    final red = <bool>[];
    for (final segment in source) {
      for (final char in segment.text.split('')) {
        if (char != '¶' && char.trim().isNotEmpty) {
          red.add(segment.wordsOfJesus);
        }
      }
    }
    final result = <ScriptureSegment>[];
    var italic = false, lastItalic = false, lastRed = false, cursor = 0;
    var buffer = StringBuffer();
    void flush() {
      if (buffer.isNotEmpty) {
        result.add(ScriptureSegment(buffer.toString(),
            wordsOfJesus: lastRed, italic: lastItalic));
      }
      buffer = StringBuffer();
    }

    for (final char in text.replaceAll('¶', '').trim().split('')) {
      if (char == '[') {
        italic = true;
        continue;
      }
      if (char == ']') {
        italic = false;
        continue;
      }
      var currentRed = lastRed;
      if (char.trim().isNotEmpty) {
        currentRed = cursor < red.length && red[cursor];
        cursor++;
      }
      if (italic != lastItalic || currentRed != lastRed) {
        flush();
      }
      lastItalic = italic;
      lastRed = currentRed;
      buffer.write(char);
    }
    flush();
    return result;
  }
}

Map<String, dynamic> _decodeReadingFormat(String source) =>
    jsonDecode(source) as Map<String, dynamic>;
