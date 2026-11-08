import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:selah/data/bible.dart';
import 'package:selah/data/daily_verse.dart';
import 'package:selah/data/user_database.dart';
import 'package:selah/features/home/daily_verse_card.dart';

class CountingDailyVerses extends DailyVerseRepository {
  int loads = 0;
  @override
  Future<DailyVerseChoice> load(Bible bible, DateTime date) async {
    loads++;
    return const DailyVerseChoice('GEN.1.1');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Bible bible;
  setUpAll(() async => bible = await Bible.load());

  testWidgets('daily verse retries stop while the app is in the background',
      (tester) async {
    final repository = CountingDailyVerses();
    await tester.pumpWidget(MaterialApp(
        home: DailyVerseCard(
            bible: bible, repository: repository, onOpen: (_) {})));
    await tester.pumpAndSettle();
    final before = repository.loads;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 2));
    expect(repository.loads, before);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repository.loads, before + 1);
    await tester.pumpWidget(const SizedBox.shrink());
    repository.dispose();
  });

  test('local selection is stable for a day and draws from all 66 books', () {
    final small = Bible([
      for (var i = 0; i < 66; i++)
        BibleBook('B$i', 'Book $i', [
          [const BibleVerse('1', 'Verse')]
        ])
    ], 'Whole canon');
    final books = <String>{};
    for (var day = 0; day < 1000; day++) {
      final date = DateTime(2026, 1, 1 + day);
      books.add(dailyVerseReference(small, date).split('.').first);
      expect(availableDailyReference(bible, dailyVerseReference(bible, date)),
          isTrue);
    }
    expect(books.length, 66);
    expect(dailyVerseReference(bible, DateTime(2026, 11, 8, 1)),
        dailyVerseReference(bible, DateTime(2026, 11, 8, 23, 59)));
  });

  test('online choice survives reopening without another request', () async {
    final database = UserDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    var requests = 0;
    http.Client client() => MockClient((request) async {
          requests++;
          expect(
              request.url.toString(), 'https://bible-api.com/data/web/random');
          return http.Response(
              jsonEncode({
                'random_verse': {
                  'book_id': 'JHN',
                  'chapter': 3,
                  'verse': 16,
                  'text': 'Network text'
                }
              }),
              200);
        });
    final first =
        DailyVerseRepository(database: database, clientFactory: client);
    final date = DateTime(2026, 11, 8);
    final choice = await first.load(bible, date);
    expect(choice.reference, 'JHN.3.16');
    expect(choice.online, isTrue);
    expect(bible.verse(choice.reference).text, isNot('Network text'));
    first.dispose();
    final reopened =
        DailyVerseRepository(database: database, clientFactory: client);
    addTearDown(reopened.dispose);
    expect((await reopened.load(bible, date)).reference, choice.reference);
    expect(requests, 1);
    await reopened.load(bible, DateTime(2026, 11, 9));
    expect(requests, 2);
  });

  test('network failures and invalid responses use local Scripture', () async {
    for (final response in [
      http.Response('offline', 503),
      http.Response('{invalid', 200),
      http.Response(
          jsonEncode({
            'random_verse': {'book_id': 'GEN', 'chapter': 999, 'verse': 1}
          }),
          200)
    ]) {
      final repository = DailyVerseRepository(
          clientFactory: () => MockClient((_) async => response));
      final choice = await repository.load(bible, DateTime(2026, 11, 8));
      expect(choice.online, isFalse);
      expect(availableDailyReference(bible, choice.reference), isTrue);
      repository.dispose();
    }
    final offline = DailyVerseRepository(
        clientFactory: () =>
            MockClient((_) async => throw http.ClientException('offline')));
    final choice = await offline.load(bible, DateTime(2026, 11, 8));
    expect(choice.reference, dailyVerseReference(bible, DateTime(2026, 11, 8)));
    expect(choice.online, isFalse);
    offline.dispose();
  });
}
