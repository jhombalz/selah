import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/data/bible.dart';
import 'package:selah/data/user_database.dart';
import 'package:selah/features/assessment/assessment_store.dart';
import 'package:selah/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'Running assessment stays visible across Home, Saved and Settings and resumes its attempt',
      (tester) async {
    final db = UserDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final bible = (await tester.runAsync(Bible.load))!;
    await tester.runAsync(() => AssessmentStore(db).start(1));
    Future<void> settle() async {
      await tester.runAsync(() async {
        await db.load();
        await Future<void>.delayed(const Duration(milliseconds: 40));
      });
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(SelahApp(
        initialBible: bible, database: db, initialData: const UserData()));
    await settle();
    expect(find.textContaining('Level 1 assessment ·'), findsOneWidget);
    await tester.tap(find.text('Saved'));
    await settle();
    expect(find.textContaining('Level 1 assessment ·'), findsOneWidget);
    expect(find.text('Your reflections'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await settle();
    expect(find.textContaining('Level 1 assessment ·'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await tester.pump();
    await settle();
    await settle();
    expect(find.text('Level 1 · Assessment'), findsOneWidget);
    expect(find.text('The timer cannot be paused.'), findsOneWidget);
    expect(find.textContaining('Level 1 assessment ·'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.load);
  });
}
