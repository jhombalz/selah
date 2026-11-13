import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/data/bible.dart';
import 'package:selah/data/user_database.dart';
import 'package:selah/features/translations/translations_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Bible bundled;
  setUpAll(() async => bundled = await Bible.load());

  for (final leaveDuringLoad in [false, true]) {
    testWidgets(
        'Translation completion preserves navigation: leave=$leaveDuringLoad',
        (tester) async {
      final db = UserDatabase(NativeDatabase.memory());
      final pending = Completer<void>();
      final started = Completer<void>();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('Bible reader remains available')),
      ));
      unawaited(navigator.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => TranslationsPage(
                database: db,
                bundled: bundled,
                activeId: 'bsb',
                onSelect: (_) async {
                  started.complete();
                  await pending.future;
                },
                onRemove: (_) async {},
              ))));
      await tester.runAsync(() => db.load());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Use OCCB'), 200);
      await tester.ensureVisible(find.text('Use OCCB'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use OCCB'));
      await tester.pump();
      expect(started.isCompleted, isTrue);
      if (leaveDuringLoad) {
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
      }
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Bible reader remains available'), findsOneWidget);
      expect(navigator.currentState!.canPop(), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await db.close();
    });
  }
}
