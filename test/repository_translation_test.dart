import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:selah/data/bible.dart';
import 'package:selah/data/bible_search.dart';
import 'package:selah/data/repository_translation.dart';
import 'package:selah/data/translations.dart';
import 'package:selah/data/user_database.dart';
import 'package:selah/data/user_backup.dart';
import 'package:selah/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Bible canon, kjv;
  late Map<String, String> sources;
  late Map<String, TranslationSpec> specs;
  setUpAll(() async {
    canon = await Bible.load();
    final archive = ZipDecoder()
        .decodeBytes(await File('web/translations/kjv.zip').readAsBytes());
    final entry =
        archive.files.singleWhere((f) => f.name == 'eng-kjv2006_vpl.txt');
    final baseline = translationCatalog.singleWhere((s) => s.id == 'kjv');
    kjv = await parseTranslation(utf8.decode(entry.content), baseline, canon);
    sources = {};
    specs = {};
    for (final id in ['niv', 'nlt']) {
      final rows = [
        for (var b = 0; b < 66; b++)
          {
            'abbrev': repositoryBookIds[b],
            'name': kjv.books[b].name,
            'chapters': [
              for (var c = 0; c < kjv.books[b].chapters.length; c++)
                List.generate(() {
                  final ref = '${kjv.books[b].id}.${c + 1}';
                  if (id == 'nlt' && ref == 'NUM.1') return 31;
                  if (id == 'nlt' && ref == 'NUM.2') return 14;
                  if (ref == '3JN.1') return 15;
                  if (id == 'nlt' && ref == 'REV.12') return 18;
                  return kjv.books[b].chapters[c].length -
                      (omittedRepositoryVerses[ref]?.length ?? 0);
                }(),
                    (v) =>
                        'Offline $id ${kjv.books[b].id}.${c + 1} source entry ${v + 1}.')
            ],
          }
      ];
      sources[id] = jsonEncode(rows);
      final catalog = translationCatalog.singleWhere((s) => s.id == id);
      specs[id] = TranslationSpec(
          id,
          catalog.title,
          catalog.abbreviation,
          'English',
          catalog.sourceId,
          sha256.convert(utf8.encode(sources[id]!)).toString(),
          'Test source attribution',
          jsonSource: catalog.jsonSource);
    }
  });
  Future<Bible> download(String id) => TranslationDownloader(
      clientFactory: () => MockClient((request) async {
            expect(request.url.toString(), specs[id]!.source);
            expect(request.headers.containsKey('api-key'), isFalse);
            return http.Response.bytes(utf8.encode(sources[id]!), 200);
          })).download(specs[id]!, canon, (_, __) {});

  test(
      'Repository editions retain all books and correct omitted/grouped verse references',
      () async {
    for (final id in ['niv', 'nlt']) {
      final bible = await download(id);
      expect(bible.books.length, 66);
      expect(
          bible.books.fold<int>(0, (sum, b) => sum + b.chapters.length), 1189);
      expect(bible.verse('MAT.17.22').text, contains('source entry 21.'));
      expect(
          bible.books[39].chapters[16].any((v) => v.number == '21'), isFalse);
      expect(bible.verse('REV.22.21').text, contains('source entry 21.'));
      expect(bible.id, id);
      if (id == 'nlt') {
        expect(bible.verse('NUM.1.44').text, contains('source entry 21.'));
        expect(bible.verse('NUM.2.9').text, contains('source entry 4.'));
        expect(bible.verse('NUM.1.22').text, contains('not present'));
      }
    }
  });
  test('Corrupt or cancelled JSON never installs a partial edition', () async {
    final bad = TranslationDownloader(
        clientFactory: () =>
            MockClient((_) async => http.Response('${sources['niv']} ', 200)));
    await expectLater(
        bad.download(specs['niv']!, canon, (_, __) {}), throwsFormatException);
    late TranslationDownloader cancelled;
    cancelled = TranslationDownloader(
        clientFactory: () =>
            MockClient((_) async => http.Response(sources['niv']!, 200)));
    await expectLater(
        cancelled.download(specs['niv']!, canon, (progress, _) {
          if (progress == .88) cancelled.cancel();
        }),
        throwsA(isA<DownloadCancelled>()));
  });
  test(
      'Offline NIV survives reopening, supports full search and keeps Scripture out of personal backups',
      () async {
    final bible = await download('niv');
    final directory =
        await Directory.systemTemp.createTemp('selah-offline-repository-');
    final path = '${directory.path}/data.sqlite';
    var db = UserDatabase(NativeDatabase(File(path)));
    try {
      final text = jsonEncode(bible.toJson());
      await db.installTranslation(
          'niv', text, sha256.convert(utf8.encode(text)).toString());
      await db.setNote('JHN.3.16', 'Private reflection',
          sourceTranslation: 'niv');
      await db
          .setPreferences({'translation': 'niv', 'readerTranslation': 'niv'});
      await db.close();
      db = UserDatabase(NativeDatabase(File(path)));
      final reopened = (await loadInstalledBible(db, 'niv'))!;
      expect((await BibleSearch(reopened).search('John 3:16')).hits.single.key,
          'JHN.3.16');
      expect(reopened.verse('REV.22.21').text, contains('Offline niv'));
      final backup =
          utf8.decode(UserBackup.create(await db.load(), canon).encode());
      expect(backup, contains('Private reflection'));
      expect(backup, isNot(contains('Offline niv')));
    } finally {
      await db.close();
      await directory.delete(recursive: true);
    }
  });
  testWidgets(
      'Previously selected NLT opens in the standard offline reader with no online mode',
      (tester) async {
    final nlt = (await tester.runAsync(() => download('nlt')))!;
    final db = UserDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.runAsync(() async {
      final text = jsonEncode(nlt.toJson());
      await db.installTranslation(
          'nlt', text, sha256.convert(utf8.encode(text)).toString());
      await db.setPreferences({
        'translation': 'cebocb',
        'readerTranslation': 'nlt',
        'lastChapter': 'JHN.3'
      });
      await db.customStatement(
          "INSERT INTO licensed_chapter_cache VALUES ('nlt:JHN.3','{}',1,1)");
    });
    await tester.pumpWidget(SelahApp(initialBible: canon, database: db));
    for (var i = 0; i < 15; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump();
    }
    expect(find.text('New Living Translation · English'), findsOneWidget);
    await tester.tap(find.text('Bible').last);
    await tester.pumpAndSettle();
    expect(find.text('NLT'), findsOneWidget);
    expect(
        find.textContaining('Offline nlt JHN.3 source entry 1.'), findsWidgets);
    expect(
        (await tester.runAsync(() =>
            db.customSelect('SELECT * FROM licensed_chapter_cache').get()))!,
        isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
