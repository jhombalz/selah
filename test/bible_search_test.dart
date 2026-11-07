import 'package:flutter_test/flutter_test.dart';
import 'package:selah/data/bible.dart';
import 'package:selah/data/bible_search.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BibleSearch complete;
  setUpAll(() async => complete = BibleSearch(await Bible.load()));

  test(
      'Cebuano, English, codes and numbered books resolve to canonical passages',
      () async {
    for (final query in ['Juan 3:16', 'JOHN3:16', 'JHN 3:16', 'Jn. 3:16']) {
      expect((await complete.search(query)).hits.single.key, 'JHN.3.16');
    }
    expect((await complete.search('1Cor 13:4')).hits.single.key, '1CO.13.4');
    expect((await complete.search('1 Juan 1:1')).hits.single.key, '1JN.1.1');
    expect(
        (await complete.search('Genesis 1:18')).hits.single.key, 'GEN.1.17-18');
    expect((await complete.search('Genesis 1:17–19')).hits.map((h) => h.key),
        ['GEN.1.17-18', 'GEN.1.19']);
    final chapter = (await complete.search('Juan 3')).hits;
    expect(chapter.length, 35); // The source combines one pair of verses.
    expect(chapter.last.verse.number, '36');
  });

  test('Invalid references and mismatched filters return useful feedback',
      () async {
    for (final query in [
      'Juan 0:1',
      'Juan 22:1',
      'Juan 3:999',
      'Juan 3:18-16',
      'Juan 3:16-9999999999999999999999999999999999',
      'Unknown 1:1',
      '3:16'
    ]) {
      final result = await complete.search(query);
      expect(result.hits, isEmpty, reason: query);
      expect(result.message, isNotEmpty, reason: query);
    }
    expect((await complete.search('Juan 3:16', bookId: 'GEN')).message,
        contains('outside'));
    expect((await complete.search('   ')).hits, isEmpty);
    expect((await complete.search('!!!')).message, isNotNull);
  });

  test(
      'Word mode matches whole words in any order; phrase mode preserves order',
      () async {
    final search = BibleSearch(const Bible([
      BibleBook('GEN', 'Genesis', [
        [
          BibleVerse('1', 'Ang gugma, ug kalinaw.'),
          BibleVerse('2', 'Kalinaw ug gugma.'),
          BibleVerse('3', 'Ang gugmahanong Dios.'),
        ]
      ]),
    ], 'Fixture'));
    expect((await search.search('GUGMA')).hits.map((h) => h.verse.number),
        ['1', '2']);
    expect((await search.search('gugma kalinaw')).hits.length, 2);
    expect(
        (await search.search('gugma ug kalinaw', phrase: true))
            .hits
            .single
            .verse
            .number,
        '1');
    expect((await search.search('"gugma ug kalinaw"')).hits.single.verse.number,
        '1');
    expect((await search.search('gugma', bookId: 'JHN')).hits, isEmpty);
    expect((await search.search('gugma', cancelled: () => true)).hits, isEmpty);
    expect((await search.search('nonexistentword')).hits, isEmpty);
  });

  test('Full bundled text searches offline and book filtering limits results',
      () async {
    final result =
        await complete.search('sa sinugdan', phrase: true, bookId: 'GEN');
    expect(result.hits.map((h) => h.key), contains('GEN.1.1'));
    expect(result.hits.every((h) => h.book.id == 'GEN'), isTrue);
  });
}
