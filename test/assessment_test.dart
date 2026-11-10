import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:selah/data/bible.dart';
import 'package:selah/data/user_database.dart';
import 'package:selah/features/assessment/assessment_catalog.dart';
import 'package:selah/features/assessment/assessment_store.dart';
import 'package:selah/features/assessment/assessment_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'Five levels contain 100 original questions with valid Scripture references',
      () async {
    final bible = await Bible.load();
    expect(assessmentBank.length, 5);
    final prompts = <String>{};
    for (final level in assessmentBank) {
      expect(level.length, 20);
      for (final q in level) {
        expect(prompts.add(q.prompt), isTrue);
        expect(q.choices.length, 4);
        expect(q.choices.toSet().length, 4);
        final parts = q.reference.split('.');
        final chapter = bible.books
            .firstWhere((b) => b.id == parts[0])
            .chapters[int.parse(parts[1]) - 1];
        final bounds = parts[2].split('-').map(int.parse).toList();
        for (var n = bounds.first; n <= bounds.last; n++) {
          expect(
              chapter.any((v) => Bible.overlaps(
                  q.reference.replaceFirst(RegExp(r'[^.]+$'), '$n'),
                  '${parts[0]}.${parts[1]}.${v.number}')),
              isTrue,
              reason: q.reference);
        }
      }
    }
  });
  late UserDatabase database;
  late DateTime now;
  late AssessmentStore store;
  setUp(() {
    database = UserDatabase(NativeDatabase.memory());
    now = DateTime.utc(2026, 11, 10, 8);
    store = AssessmentStore(database, clock: () => now);
  });
  tearDown(() => database.close());

  testWidgets(
      'Start warning, saved choice and submission results hide answer keys',
      (tester) async {
    tester.view.physicalSize = const Size(700, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Future<void> flush() async {
      await tester.runAsync(() async {
        await database.load();
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();
    }

    Future<void> tap(String text) async {
      final finder = find.text(text);
      if (finder.evaluate().isEmpty) {
        await tester.scrollUntilVisible(finder, 250,
            scrollable: find.byType(Scrollable).first);
      }
      await Scrollable.ensureVisible(tester.element(finder), alignment: 0.3);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pump();
      await flush();
    }

    await tester
        .pumpWidget(MaterialApp(home: AssessmentPage(database: database)));
    await flush();
    await tap('Start Level 1');
    expect(find.text('The timer cannot be paused'), findsOneWidget);
    expect(await tester.runAsync(store.load), isEmpty);
    await tap('Start timed assessment');
    final a = (await tester.runAsync(store.load))!.single;
    final q = assessmentBank[0][a.order.first];
    await tap(q.choices[1]);
    expect(
        (await tester.runAsync(store.load))!.single.answers[a.order.first], 1);
    await tap('Submit assessment');
    expect(find.text('Submit assessment?'), findsOneWidget);
    await tap('Submit');
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('0/20 · 0%'), findsOneWidget);
    expect(find.text(q.prompt), findsNothing);
    for (final choice in q.choices) {
      expect(find.text(choice), findsNothing);
    }
    expect((await tester.runAsync(store.load))!.single.submitted, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('Locked levels, one active attempt, 80% passing and sequential unlock',
      () async {
    await expectLater(store.start(2), throwsStateError);
    final a = await store.start(1);
    expect(a.order.toSet().length, 20);
    expect(a.deadline.difference(a.startedAt), const Duration(hours: 3));
    await expectLater(store.start(1), throwsStateError);
    for (var i = 0; i < 16; i++) {
      await store.answer(a.id, i, 0);
    }
    now = now.add(const Duration(minutes: 10));
    await store.submit(a.id);
    final done = (await store.load()).first;
    expect(done.score, 16);
    expect(done.percent, 80);
    expect(done.passed, isTrue);
    expect(AssessmentStore.unlocked(2, [done]), isTrue);
    expect(AssessmentStore.unlocked(3, [done]), isFalse);
    expect(await store.start(2), isA<AssessmentAttempt>());
    await store.answer(a.id, 19, 0);
    expect((await store.load()).firstWhere((r) => r.id == a.id).score, 16);
  });
  test('Cooldown is 24 hours from submission, not start or local midnight',
      () async {
    final a = await store.start(1);
    now = now.add(const Duration(hours: 2));
    await store.submit(a.id);
    expect((await store.load()).first.passed, isFalse);
    now = now.add(const Duration(hours: 23, minutes: 59));
    await expectLater(store.start(1), throwsStateError);
    now = now.add(const Duration(minutes: 1));
    expect(await store.start(1), isA<AssessmentAttempt>());
  });
  test(
      'Deadline auto-submits saved choices, unanswered are wrong and cooldown uses expiry',
      () async {
    final a = await store.start(1);
    await store.answer(a.id, 2, 0, flag: true, current: 5);
    await store.answer(a.id, 3, 1);
    now = a.deadline.add(const Duration(hours: 25));
    final expired = (await store.load()).single;
    expect(expired.submittedAt, a.deadline);
    expect(expired.score, 1);
    expect(expired.current, 5);
    expect(expired.flagged, {2});
    expect(await store.start(1), isA<AssessmentAttempt>());
  });
  test(
      'Attempt survives database reopening with original deadline and choice order',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('selah-assessment-');
    final file = File('${directory.path}/test.sqlite');
    final first = UserDatabase(NativeDatabase(file));
    final firstStore = AssessmentStore(first, clock: () => now);
    final a = await firstStore.start(1);
    await firstStore.answer(a.id, 7, 2, flag: true, current: 9);
    await first.close();
    final second = UserDatabase(NativeDatabase(file));
    try {
      now = now.add(const Duration(hours: 1));
      final loaded =
          (await AssessmentStore(second, clock: () => now).load()).single;
      expect(loaded.deadline, a.deadline);
      expect(loaded.answers, {7: 2});
      expect(loaded.options(7), a.options(7));
      expect(loaded.flagged, {7});
      expect(loaded.current, 9);
    } finally {
      await second.close();
      await directory.delete(recursive: true);
    }
  });
}
