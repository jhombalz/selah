import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    final repository = DailyVerseRepository();
    addTearDown(repository.dispose);
    final date = DateTime(2026, 11, 13);
    expect((await repository.load(bible, date)).reference,
        dailyVerseReference(bible, date));
  });
}
