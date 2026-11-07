import 'package:flutter_test/flutter_test.dart';
import 'package:selah/data/bible.dart';
import 'package:selah/features/home/daily_verse_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'Daily references exist in the bundled Bible and cover all requested verses',
      () async {
    final bible = await Bible.load();
    for (final reference in dailyVerseReferences) {
      final verse = bible.verse(reference);
      expect(verse.text, isNotEmpty);
      expect(verse.text, isNot(contains('not present')));
      final parts = reference.split('.');
      final requested = parts.last.split('-').map(int.parse).toList();
      final chapter = bible.books
          .firstWhere((b) => b.id == parts.first)
          .chapters[int.parse(parts[1]) - 1];
      for (var number = requested.first; number <= requested.last; number++) {
        expect(
            chapter.any((v) => Bible.overlaps(
                reference.replaceFirst(RegExp(r'[^.]+$'), '$number'),
                '${parts[0]}.${parts[1]}.${v.number}')),
            isTrue);
      }
    }
  });

  test(
      'Daily selection stays stable within a local day and changes at midnight',
      () {
    expect(dailyVerseReference(DateTime(2026, 11, 7, 1)),
        dailyVerseReference(DateTime(2026, 11, 7, 23, 59)));
    expect(dailyVerseReference(DateTime(2026, 11, 8)),
        isNot(dailyVerseReference(DateTime(2026, 11, 7))));
    expect(
        dailyVerseReference(DateTime(2024, 2, 29)), isIn(dailyVerseReferences));
  });
}
