import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:selah/data/bible.dart';
import 'package:selah/data/commentary.dart';
import 'package:selah/data/scripture_range.dart';
import 'package:selah/data/user_database.dart';
import 'package:selah/features/study/study_notes_sheet.dart';

Map<String, dynamic> sample() => {
      'commentary': {
        'id': 'tyndale',
        'language': 'eng',
        'licenseUrl': studyNotesLicense,
        'licenseNotes': 'Source formatting notice',
        'licenseNotice': 'Test contributor credit'
      },
      'book': {'id': 'JHN'},
      'chapter': {
        'number': 3,
        'content': [
          {
            'type': 'verse',
            'number': 14,
            'text': '3:14-15 First passage note.'
          },
          {
            'type': 'verse',
            'number': 16,
            'text': '3:16-21 A note covering the selected passage.'
          },
          {'type': 'verse', 'number': 18, 'text': '3:18 An individual note.'},
        ]
      },
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late UserDatabase database;
  setUp(() => database = UserDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());
  test(
      'Range matching handles grouped verses without interpreting prose cross references',
      () {
    expect(
        const StudyNote(16, '3:16-21 A note')
            .matches(ScriptureRange.parse('JHN.3.18')),
        isTrue);
    expect(
        const StudyNote(16, '3:16–21 A note')
            .matches(ScriptureRange.parse('JHN.3.22')),
        isFalse);
    expect(
        const StudyNote(1, '1:1–2:3 A chapter-spanning overview')
            .matches(ScriptureRange.parse('GEN.1.31')),
        isTrue);
    expect(
        const StudyNote(1, '3:1 See also 3:18.')
            .matches(ScriptureRange.parse('JHN.3.18')),
        isFalse);
  });
  test(
      'Online chapters save source credits and open offline without another request',
      () async {
    var calls = 0;
    final first = StudyNotesRepository(database,
        clientFactory: () => MockClient((request) async {
              calls++;
              expect(request.url.toString(),
                  'https://bible.helloao.org/api/c/tyndale/JHN/3.simple.json');
              return http.Response(jsonEncode(sample()), 200);
            }));
    final online = await first.load('JHN', 3);
    expect(online.cacheFailed, isFalse);
    expect(online.notes.length, 3);
    first.dispose();
    final offline = StudyNotesRepository(database,
        clientFactory: () => throw StateError('Must use cache'));
    addTearDown(offline.dispose);
    final saved = await offline.load('JHN', 3);
    expect(saved.cached, isTrue);
    expect(saved.licenseNotice, 'Test contributor credit');
    expect(calls, 1);
    final backup = await database.load();
    expect(backup.notes, isEmpty);
    expect(backup.preferences, isEmpty);
  });
  test(
      'Failed refresh keeps saved notes and removing cache does not remove personal writing',
      () async {
    var fail = false;
    final repo = StudyNotesRepository(database,
        clientFactory: () => MockClient((_) async {
              if (fail) throw http.ClientException('Offline');
              return http.Response(jsonEncode(sample()), 200);
            }));
    addTearDown(repo.dispose);
    await repo.load('JHN', 3);
    await database.setNote('JHN.3.16', 'My reflection');
    fail = true;
    expect((await repo.load('JHN', 3, refresh: true)).refreshFailed, isTrue);
    await repo.remove('JHN', 3);
    expect((await database.load()).notes['JHN.3.16'], 'My reflection');
    await expectLater(
        repo.load('JHN', 3), throwsA(isA<http.ClientException>()));
  });
  test(
      'Missing commentary is empty; wrong chapters and incompatible licenses are rejected',
      () async {
    final absent = StudyNotesRepository(database,
        clientFactory: () => MockClient((_) async => http.Response('', 404)));
    addTearDown(absent.dispose);
    expect((await absent.load('PHM', 1)).notes, isEmpty);
    final wrong = sample()..['book'] = {'id': 'GEN'};
    expect(() => StudyChapter.fromApi(wrong, 'JHN', 3), throwsFormatException);
    final changed = sample();
    (changed['commentary'] as Map)['licenseUrl'] =
        'https://example.com/restricted';
    expect(
        () => StudyChapter.fromApi(changed, 'JHN', 3), throwsFormatException);
  });
  testWidgets(
      'Phone sheet matches the selected range, offers chapter context and source credits',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bible = (await tester.runAsync(Bible.load))!;
    final repo = StudyNotesRepository(database,
        clientFactory: () =>
            MockClient((_) async => http.Response(jsonEncode(sample()), 200)));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StudyNotesSheet(
                bible: bible,
                database: database,
                reference: 'JHN.3.18',
                repository: repo))));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('3:16-21 A note covering the selected passage.'),
        findsOneWidget);
    expect(find.text('3:14-15 First passage note.'), findsNothing);
    expect(
        tester.getTopLeft(find.text('3:18 An individual note.')).dy,
        lessThan(tester
            .getTopLeft(
                find.text('3:16-21 A note covering the selected passage.'))
            .dy));
    await tester.tap(find.text('Whole chapter'));
    await tester.pumpAndSettle();
    expect(find.text('3:14-15 First passage note.'), findsOneWidget);
    await tester.tap(find.text('Source & license'));
    await tester.pumpAndSettle();
    expect(find.text('Source and license'), findsOneWidget);
    expect(find.text(studyNotesLicense), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
