import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
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

  test('daily reflection rotates curated passages without repeats for 80 days',
      () {
    expect(dailyMemoryVerses.length, 80);
    expect(dailyMemoryVerses.toSet().length, 80);
    for (final reference in dailyMemoryVerses) {
      expect(availableDailyReference(bible, reference), isTrue,
          reason: reference);
    }
    final chosen = <String>{};
    for (var day = 0; day < 80; day++) {
      final date = DateTime(2026, 1, 1 + day);
      final ref = dailyVerseReference(bible, date);
      chosen.add(ref);
      expect(dailyMemoryVerses, contains(ref));
      expect(
          ref,
          dailyVerseReference(
              bible, DateTime(date.year, date.month, date.day, 23, 59)));
    }
    expect(chosen.length, 80);
  });

  test(
      'legacy random cached verse is replaced and daily choice survives reopening',
      () async {
    final database = UserDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final date = DateTime(2026, 11, 13);
    await database.cacheDailyVerse(dailyVerseDay(date), '1CH.1.1', true);
    final first = DailyVerseRepository(database: database);
    final expected = dailyVerseReference(bible, date);
    final choice = await first.load(bible, date);
    expect(choice.reference, expected);
    expect(choice.online, isFalse);
    first.dispose();
    final reopened = DailyVerseRepository(database: database);
    addTearDown(reopened.dispose);
    expect((await reopened.load(bible, date)).reference, expected);
    expect(
        (await reopened.load(bible, date.add(const Duration(days: 1))))
            .reference,
        isNot(expected));
  });

  test('daily verse needs neither internet nor a database', () async {
    final repository = DailyVerseRepository(
        clientFactory: () =>
            MockClient((_) async => throw http.ClientException('Offline')));
    addTearDown(repository.dispose);
    final date = DateTime(2026, 11, 13);
    expect((await repository.load(bible, date)).reference,
        dailyVerseReference(bible, date));
  });
  test(
      'Online featured reference is cached for the day without Bible API calls',
      () async {
    final db = UserDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    var requests = 0;
    http.Client client() => MockClient((request) async {
          requests++;
          expect(request.url.toString(), DailyVerseRepository.feed);
          expect(request.headers.containsKey('api-key'), isFalse);
          return http.Response(
              jsonEncode({
                'version': 1,
                'references': dailyMemoryVerses,
                'days': {'2026-11-13': 'JHN.3.16'}
              }),
              200);
        });
    final repository =
        DailyVerseRepository(database: db, clientFactory: client);
    final date = DateTime(2026, 11, 13);
    final result = await repository.load(bible, date);
    expect(result.reference, 'JHN.3.16');
    expect(result.online, isTrue);
    repository.dispose();
    final reopened = DailyVerseRepository(database: db, clientFactory: client);
    addTearDown(reopened.dispose);
    expect((await reopened.load(bible, date)).reference, 'JHN.3.16');
    expect(requests, 1);
  });
  test('An invalid online reference retains the curated offline choice',
      () async {
    final repository = DailyVerseRepository(
        clientFactory: () => MockClient((_) async => http.Response(
            jsonEncode({
              'version': 1,
              'references': ['1CH.1.1']
            }),
            200)));
    addTearDown(repository.dispose);
    final date = DateTime(2026, 11, 13);
    final result = await repository.load(bible, date);
    expect(result.reference, dailyVerseReference(bible, date));
    expect(result.online, isFalse);
  });
}
