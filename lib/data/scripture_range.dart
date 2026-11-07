class ScriptureRange {
  final String book;
  final int chapter, start, end;
  const ScriptureRange(this.book, this.chapter, this.start, this.end);

  factory ScriptureRange.parse(String reference) {
    final match =
        RegExp(r'^(\w+)\.(\d+)\.(\d+)(?:-(\d+))?$').firstMatch(reference);
    if (match == null) {
      throw FormatException('Invalid Scripture reference', reference);
    }
    final chapter = int.parse(match[2]!);
    final start = int.parse(match[3]!);
    final end = int.parse(match[4] ?? match[3]!);
    if (chapter < 1 || start < 1 || end < start) {
      throw FormatException('Invalid verse range', reference);
    }
    return ScriptureRange(match[1]!, chapter, start, end);
  }

  static String between(String first, String last) {
    final a = ScriptureRange.parse(first);
    final b = ScriptureRange.parse(last);
    if (a.book != b.book || a.chapter != b.chapter) {
      throw ArgumentError('A selection must stay within one chapter.');
    }
    return ScriptureRange(
            a.book,
            a.chapter,
            a.start < b.start ? a.start : b.start,
            a.end > b.end ? a.end : b.end)
        .reference;
  }

  String get reference => '$book.$chapter.$start${start == end ? '' : '-$end'}';

  bool overlaps(ScriptureRange other) =>
      book == other.book &&
      chapter == other.chapter &&
      start <= other.end &&
      other.start <= end;

  List<ScriptureRange> without(ScriptureRange other) {
    if (!overlaps(other)) return [this];
    return [
      if (start < other.start)
        ScriptureRange(book, chapter, start, other.start - 1),
      if (end > other.end) ScriptureRange(book, chapter, other.end + 1, end),
    ];
  }
}

/// Recolor only the selected passage, retaining highlights outside its bounds.
Map<String, int> recolorPassage(
    Map<String, int> existing, String reference, int? color) {
  final selection = ScriptureRange.parse(reference);
  final result = <String, int>{};
  for (final entry in existing.entries) {
    for (final remainder
        in ScriptureRange.parse(entry.key).without(selection)) {
      result[remainder.reference] = entry.value;
    }
  }
  if (color != null) result[selection.reference] = color;
  return result;
}
