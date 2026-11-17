import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:drift/native.dart';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:selah/data/bible.dart';
import 'package:selah/data/sqlite_translation.dart';
import 'package:selah/data/translations.dart';
import 'package:selah/data/user_database.dart';
import 'package:selah/features/translations/translations_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Bible canon;
  late Uint8List compressed;
  setUpAll(() async {
    canon = await Bible.load();
    final dir = await Directory.systemTemp.createTemp('selah-mbb-fixture-');
    final file = File('${dir.path}/fixture.sqlite');
    final db = sqlite3.open(file.path);
    try {
      db.execute('CREATE TABLE info(name TEXT,value TEXT)');
      db.execute('CREATE TABLE books(book_number INTEGER,long_name TEXT)');
      db.execute(
          'CREATE TABLE verses(book_number INTEGER,chapter INTEGER,verse INTEGER,text TEXT)');
      db.execute(
          "INSERT INTO info VALUES('description','Magandang Balita Biblia, 2005'),('language','tl'),('detailed_info','Test attribution')");
      db.execute('BEGIN');
      for (var b = 0; b < 66; b++) {
        db.execute('INSERT INTO books VALUES(?,?)',
            [myBibleCanonNumbers[b], b == 39 ? 'Mateo' : canon.books[b].name]);
        for (var c = 1; c <= canon.books[b].chapters.length; c++) {
          db.execute('INSERT INTO verses VALUES(?,?,1,?)',
              [myBibleCanonNumbers[b], c, 'Original words<f>note link</f>']);
        }
      }
      db.execute("INSERT INTO verses VALUES(10,6,2,'')");
      db.execute('COMMIT');
    } finally {
      db.close();
    }
    compressed =
        Uint8List.fromList(GZipEncoder().encode(await file.readAsBytes()));
    await file.delete();
    await dir.delete();
  });

  test(
      'Portable SQLite import keeps canonical references, local names and merged verses',
      () async {
    final bible = await parseSqliteTranslation(
        (compressed, canon, 'fixture', 'Attribution'));
    expect(bible.books.length, 66);
    expect(bible.books.fold<int>(0, (n, b) => n + b.chapters.length), 1189);
    expect(bible.books[39].name, 'Mateo');
    expect(bible.language, 'Tagalog');
    expect(bible.verse('GEN.6.2').number, '1-2');
    expect(bible.verse('GEN.6.2').text, 'Original words');
    expect(bible.licenseText, contains('Test attribution'));
  });

  testWidgets(
      'Tagalog downloads show MBB05 and retain ULB only when already installed',
      (tester) async {
    final db = UserDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    Future<void> show(int key) async {
      await tester.pumpWidget(MaterialApp(
          key: ValueKey('root-$key'),
          home: TranslationsPage(
              key: ValueKey(key),
              database: db,
              bundled: canon,
              activeId: 'cebocb',
              onSelect: (_) async {},
              onRemove: (_) async {})));
      await tester.runAsync(db.load);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tagalog'));
      await tester.pumpAndSettle();
    }

    await show(1);
    expect(find.text('Download MBB05'), findsOneWidget);
    expect(find.text('Download ULB'), findsNothing);
    final legacy = Bible(canon.books, 'Legacy ULB', id: 'tglulb');
    final content = jsonEncode(legacy.toJson());
    await tester.runAsync(() => db.installTranslation(
        'tglulb', content, sha256.convert(utf8.encode(content)).toString()));
    expect(
        (await tester.runAsync(db.installedTranslations))!
            .containsKey('tglulb'),
        isTrue);
    await show(2);
    expect(find.text('Download MBB05'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Use ULB'), 200);
    expect(find.text('Use ULB'), findsOneWidget);
    expect(find.textContaining('Previous Tagalog edition'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test('SQLite download checks package integrity before import', () async {
    final spec = TranslationSpec('fixture', 'Test MBB', 'MBB05', 'Tagalog',
        'MBB', sha256.convert(compressed).toString(), 'Attribution',
        sqliteSource: 'https://example.test/mbb.gz');
    final changed = Uint8List.fromList(compressed)..[0] ^= 1;
    final downloader = TranslationDownloader(
        clientFactory: () =>
            MockClient((_) async => http.Response.bytes(changed, 200)));
    await expectLater(
        downloader.download(spec, canon, (_, __) {}), throwsFormatException);
  });

  test(
      'MyBible formatting removes footnote links and preserves poetry/table words',
      () {
    expect(
        plainMyBibleText(
            '<pb/><t>Poetry &amp; words<f>link</f></t><n>[Table heading]</n>'),
        'Poetry & words\n[Table heading]');
    expect(() => plainMyBibleText('<script>Unexpected markup</script>'),
        throwsFormatException);
  });
}
