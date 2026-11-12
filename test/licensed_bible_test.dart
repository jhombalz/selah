import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:selah/data/bible.dart';
import 'package:selah/data/licensed_bible.dart';
import 'package:selah/data/daily_verse.dart';
import 'package:selah/data/user_backup.dart';
import 'package:selah/data/user_database.dart';
import 'package:selah/features/reader/licensed_reader_page.dart';
import 'package:selah/features/reader/reader_toolbar.dart';
import 'package:selah/features/reader/chapter_navigation.dart';
import 'package:selah/main.dart';

Map<String, dynamic> chapterData(String book, int chapter, {String? edition}) =>
    {
      'id': '$book.$chapter',
      'bibleId': edition ?? licensedEditions.first.apiId,
      'bookId': book,
      'number': '$chapter',
      'copyright': 'Test publisher attribution. All rights reserved.',
      'verseCount': 2,
      'content': [
        {
          'type': 'tag',
          'name': 'para',
          'attrs': {'style': 's1'},
          'items': [
            {'type': 'text', 'text': 'A test heading'}
          ]
        },
        {
          'type': 'tag',
          'name': 'para',
          'attrs': {'style': 'p'},
          'items': [
            {
              'type': 'text',
              'text': 'First test sentence. ',
              'attrs': {'verseId': '$book.$chapter.1'}
            },
            {
              'type': 'tag',
              'name': 'char',
              'attrs': {'style': 'it'},
              'items': [
                {
                  'type': 'text',
                  'text': 'Its continuation.',
                  'attrs': {'verseId': '$book.$chapter.1'}
                }
              ]
            },
            {
              'type': 'text',
              'text': 'Second test sentence.',
              'attrs': {'verseId': '$book.$chapter.2'}
            },
          ]
        },
      ]
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late UserDatabase db;
  setUp(() => db = UserDatabase(NativeDatabase.memory()));
  testWidgets(
      'Selected NLT stays in Bible tab and supplies Home and Saved wording',
      (tester) async {
    final canon = (await tester.runAsync(Bible.load))!;
    final nlt = licensedEditions.last;
    final requests = <String>[];
    final daily = dailyVerseReference(canon, DateTime.now()).split('.');
    final repository = LicensedBibleRepository(db, apiKey: 'test-key',
        client: MockClient((request) async {
      final ref = request.url.pathSegments.last.split('.');
      requests.add(request.url.path);
      final data = chapterData(ref[0], int.parse(ref[1]), edition: nlt.apiId);
      final number = int.parse(daily[2].split('-').first);
      if (ref[0] == daily[0] && ref[1] == daily[1] && number > 2) {
        ((data['content'] as List).last['items'] as List).add({
          'type': 'text',
          'text': 'Daily selected wording.',
          'attrs': {'verseId': '${ref[0]}.${ref[1]}.$number'},
        });
      }
      return http.Response(jsonEncode({'data': data}), 200);
    }));
    addTearDown(repository.dispose);
    await tester.runAsync(() async {
      await db
          .setPreferences({'readerTranslation': 'nlt', 'lastChapter': 'JHN.3'});
      await db.setBookmark('JHN.3.1', true);
      await db.cacheDailyVerse(dailyVerseDay(DateTime.now()), 'JHN.3.1', true);
    });
    final data = (await tester.runAsync(db.load))!;
    await tester.pumpWidget(SelahApp(
        initialBible: canon,
        database: db,
        initialData: data,
        licensedRepository: repository));
    Future<void> settle() async {
      for (var i = 0; i < 15; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
    }

    await settle();
    expect(find.text('New Living Translation · English'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('VERSE OF THE DAY'), 300,
        scrollable: find.byType(Scrollable).first);
    await settle();
    expect(
        find.textContaining(int.parse(daily[2].split('-').first) > 2
            ? 'Daily selected wording.'
            : 'First test sentence.'),
        findsOneWidget);
    expect(find.textContaining('· NLT'), findsWidgets);
    await tester.tap(find.text('Bible').last);
    await settle();
    expect(find.text('NLT'), findsOneWidget);
    expect(find.textContaining('First test sentence.'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
    await tester.tap(find.byTooltip('Next chapter'));
    await settle();
    expect(find.text('John 4'), findsWidgets);
    await tester.tap(find.text('Saved').last);
    await settle();
    expect(find.text('John 3:1 · NLT'), findsOneWidget);
    expect(find.textContaining('First test sentence.'), findsOneWidget);
    expect(find.textContaining('Sa sinugdan'), findsNothing);
    expect(requests.where((r) => r.endsWith('JHN.3')).length, 1);
    await tester.tap(find.text('Bible').last);
    await settle();
    expect(find.text('John 4'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, skip: LicensedBibleAccess.key.isEmpty);
  testWidgets(
      'Online reader uses shared AA and chapter controls and preserves reading focus',
      (tester) async {
    final canon = (await tester.runAsync(Bible.load))!;
    final repository = LicensedBibleRepository(db, apiKey: 'test-key',
        client: MockClient((request) async {
      final chapter = int.parse(request.url.pathSegments.last.split('.').last);
      final data = chapterData('JHN', chapter);
      data['content'] = [
        {
          'type': 'tag',
          'name': 'para',
          'attrs': {'style': 'p'},
          'items': [
            for (var verse = 1; verse <= 20; verse++)
              {
                'type': 'text',
                'text':
                    'A source sentence for reading and reflecting in this test passage. ',
                'attrs': {'verseId': 'JHN.$chapter.$verse'},
              }
          ],
        }
      ];
      return http.Response(jsonEncode({'data': data}), 200);
    }));
    addTearDown(repository.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: LicensedReaderPage(
            edition: licensedEditions.first,
            canon: canon,
            database: db,
            repository: repository,
            initialReference: 'JHN.3')));
    Future<void> settle() async {
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    await settle();
    expect(find.byType(ReaderToolbar), findsOneWidget);
    expect(find.byType(ChapterNavigation), findsOneWidget);
    expect(find.byTooltip('Smaller text'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('text-size')));
    await tester.pumpAndSettle();
    expect(find.text('Reading preferences'), findsOneWidget);
    await tester.tap(find.byTooltip('Larger text'));
    await settle();
    expect((await tester.runAsync(db.load))!.preferences['fontSize'], '22.0');
    await tester.tap(find.byTooltip('Close text size'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderToolbar), findsNothing);
    await tester.tap(find.byTooltip('Next chapter'));
    await settle();
    expect(find.byType(ReaderToolbar), findsNothing);
    expect(find.text('John 4'), findsWidgets);
    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 3000));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderToolbar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  tearDown(() => db.close());
  final niv = licensedEditions.first;

  test(
      'Concurrent and repeated chapter reads use one request and retain attribution',
      () async {
    var calls = 0;
    final repository = LicensedBibleRepository(db, apiKey: 'test-key',
        client: MockClient((request) async {
      calls++;
      expect(request.url.host, 'rest.api.bible');
      expect(request.headers['api-key'], 'test-key');
      expect(request.url.query, isNot(contains('test-key')));
      return http.Response(jsonEncode({'data': chapterData('JHN', 3)}), 200);
    }));
    addTearDown(repository.dispose);
    final results = await Future.wait(
        [repository.load(niv, 'JHN', 3), repository.load(niv, 'JHN', 3)]);
    expect(calls, 1);
    expect(results.first.verses.first.text,
        'First test sentence. Its continuation.');
    expect(
        results.first.verses.first.readingFormat!.headings, ['A test heading']);
    expect((await repository.load(niv, 'JHN', 3)).cached, isTrue);
    expect(calls, 1);
    final offline = LicensedBibleRepository(db,
        apiKey: 'test-key',
        client: MockClient((_) async => throw Exception('offline')));
    addTearDown(offline.dispose);
    expect((await offline.load(niv, 'JHN', 3)).copyright,
        contains('Test publisher'));
  });

  test(
      'Cache expires at 30 days and cannot be revived by offline refresh or a future timestamp',
      () async {
    var date = DateTime.utc(2026, 11, 12), online = true, calls = 0;
    final repository = LicensedBibleRepository(db,
        apiKey: 'test-key',
        now: () => date,
        client: MockClient((_) async {
          calls++;
          if (!online) throw Exception('offline');
          return http.Response(
              jsonEncode({'data': chapterData('GEN', 1)}), 200);
        }));
    addTearDown(repository.dispose);
    await repository.load(niv, 'GEN', 1);
    online = false;
    date = date.add(const Duration(days: 29));
    expect((await repository.load(niv, 'GEN', 1, refresh: true)).refreshFailed,
        isTrue);
    date = date.add(const Duration(days: 1));
    await expectLater(repository.load(niv, 'GEN', 1), throwsStateError);
    expect(await db.customSelect('SELECT * FROM licensed_chapter_cache').get(),
        isEmpty);
    expect(calls, 3);
    final future = DateTime.utc(2027);
    await db.customStatement(
        'INSERT INTO licensed_chapter_cache VALUES (?,?,?,?)', [
      'niv:GEN.1',
      jsonEncode(chapterData('GEN', 1)),
      future.millisecondsSinceEpoch,
      future.millisecondsSinceEpoch
    ]);
    await expectLater(repository.load(niv, 'GEN', 1), throwsStateError);
  });

  test(
      'Wrong edition is rejected; quota errors are clear and caches are excluded from user backups',
      () async {
    expect(
        () => LicensedBibleRepository.parse(
            chapterData('JHN', 3, edition: licensedEditions.last.apiId),
            niv,
            'JHN',
            3,
            DateTime.now()),
        throwsFormatException);
    final repository = LicensedBibleRepository(db,
        apiKey: 'test-key',
        client: MockClient((_) async => http.Response('{}', 429)));
    addTearDown(repository.dispose);
    await expectLater(
        repository.load(niv, 'JHN', 3),
        throwsA(isA<StateError>()
            .having((e) => e.message, 'message', contains('limit'))));
    final canon = await Bible.load();
    await db.setNote('JHN.3.1', 'My reflection', sourceTranslation: 'niv');
    await db.customStatement(
        'INSERT INTO licensed_chapter_cache VALUES (?,?,?,?)', [
      'niv:JHN.3',
      jsonEncode(chapterData('JHN', 3)),
      DateTime.now().millisecondsSinceEpoch,
      0
    ]);
    final backup = await BackupService(db, canon).capture();
    final json = utf8.decode(backup.encode());
    expect(json, contains('My reflection'));
    expect(json, isNot(contains('First test sentence')));
    await repository.clear();
    expect((await db.load()).notes['JHN.3.1'], 'My reflection');
  });

  test('Only the 60 most recently accessed chapters are retained', () async {
    var date = DateTime.utc(2026, 11, 12);
    final repository = LicensedBibleRepository(db,
        apiKey: 'test-key',
        now: () => date,
        client: MockClient((request) async {
          final chapter = int.parse(request.url.path.split('.').last);
          return http.Response(
              jsonEncode({'data': chapterData('PSA', chapter)}), 200);
        }));
    addTearDown(repository.dispose);
    for (var chapter = 1; chapter <= 61; chapter++) {
      await repository.load(niv, 'PSA', chapter);
      date = date.add(const Duration(seconds: 1));
    }
    final rows = await db
        .customSelect('SELECT reference FROM licensed_chapter_cache')
        .get();
    expect(rows.length, 60);
    expect(rows.map((r) => r.read<String>('reference')),
        isNot(contains('niv:PSA.1')));
  });

  testWidgets(
      'Reader opens chapters, bookmarks, handles offline navigation, and resumes from cache',
      (tester) async {
    final canon = await tester.runAsync(Bible.load);
    var online = true;
    final repository = LicensedBibleRepository(db, apiKey: 'test-key',
        client: MockClient((request) async {
      if (!online) throw Exception('offline');
      final chapter = int.parse(request.url.path.split('.').last);
      return http.Response(
          jsonEncode({'data': chapterData('JHN', chapter)}), 200);
    }));
    addTearDown(repository.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: LicensedReaderPage(
            edition: niv,
            canon: canon!,
            database: db,
            repository: repository,
            initialReference: 'JHN.3')));
    Future<void> settle() async {
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    await settle();
    expect(find.text('Test publisher attribution. All rights reserved.'),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('licensed-verse-JHN.3.1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookmark passage'));
    await settle();
    expect((await tester.runAsync(() => db.load()))!.bookmarks,
        contains('JHN.3.1'));
    await tester.tap(find.byKey(const ValueKey('licensed-verse-JHN.3.1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Write a note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'A private NIV reflection');
    await tester.tap(find.text('Save note'));
    await settle();
    final saved = await tester.runAsync(() => db.load());
    expect(saved!.notes['JHN.3.1'], 'A private NIV reflection');
    expect(saved.noteTranslations['JHN.3.1'], 'niv');
    online = false;
    await tester.tap(find.byTooltip('Next chapter'));
    await settle();
    expect(find.textContaining('Internet is needed'), findsOneWidget);
    expect(find.byKey(const ValueKey('licensed-verse-JHN.3.1')), findsNothing);
    await tester.tap(find.byTooltip('Previous chapter'));
    await settle();
    expect(find.textContaining('Saved chapter'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('licensed-verse-JHN.3.1')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
