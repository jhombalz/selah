import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/main.dart';
import 'package:selah/data/bible.dart';
import 'package:selah/data/user_database.dart';
import 'package:drift/native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Bible bible;
  late UserDatabase database;
  setUpAll(() async => bible = await Bible.load());
  setUp(() => database = UserDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  Future<void> tapAndSave(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      await database.load();
      await Future<void>.delayed(Duration.zero);
      await database.load();
    });
    await tester.pumpAndSettle();
  }

  test('Bundled Bible includes the complete canon and stable verse references',
      () {
    expect(bible.books.length, 66);
    expect(bible.books.fold<int>(0, (sum, b) => sum + b.chapters.length), 1189);
    expect(bible.books.first.id, 'GEN');
    expect(bible.books.last.id, 'REV');
    expect(bible.verse('GEN.1.1').text,
        'Sa sinugdan gimugna sa Dios ang kalangitan ug ang kalibotan.');
    expect(bible.verse('GEN.1.17-18').number, '17-18');
    expect(bible.reference('JHN.3.16'), 'Juan 3:16');
    final references = <String>{};
    for (final book in bible.books) {
      for (int chapter = 0; chapter < book.chapters.length; chapter++) {
        expect(book.chapters[chapter], isNotEmpty);
        for (final verse in book.chapters[chapter]) {
          expect(verse.text.trim(), isNotEmpty);
          expect(references.add('${book.id}.${chapter + 1}.${verse.number}'),
              isTrue);
        }
      }
    }
    expect(references.length, 30552);
  });
  testWidgets('Reader supports mobile and desktop navigation', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(SelahApp(
        initialBible: bible,
        database: database,
        initialData: const UserData()));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Continue Reading'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.text('Your reflections'), findsOneWidget);
    tester.view.physicalSize = const Size(1280, 900);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chapter navigation and bookmarks use Scripture references',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(SelahApp(
        initialBible: bible,
        database: database,
        initialData: const UserData()));
    await tapAndSave(tester, find.text('Continue Reading'));
    await tester.tap(find.byKey(const ValueKey('verse-GEN.1.1')));
    await tester.pumpAndSettle();
    await tapAndSave(tester, find.text('Bookmark verse'));
    await tapAndSave(tester, find.byTooltip('Next chapter'));
    expect(find.text('Genesis 2'), findsWidgets);
    await tapAndSave(tester, find.byTooltip('Previous chapter'));
    expect(find.text('Genesis 1'), findsWidgets);
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.text('Genesis 1:1 · OCCB'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Changing chapters keeps hidden controls hidden until scrolling to the top',
      (tester) async {
    Future<void> settleReader() async {
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(SelahApp(
        initialBible: bible,
        database: database,
        initialData: const UserData()));
    await tapAndSave(tester, find.text('Continue Reading'));
    final reader = find.byType(SingleChildScrollView).first;
    await tester.drag(reader, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    await settleReader();
    await tester.tap(find.byTooltip('Next chapter'));
    await settleReader();
    expect(find.text('Genesis 2'), findsWidgets);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.drag(reader, const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    await tester.drag(reader, const Offset(0, 1500));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await settleReader();
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(database.load);
  });

  testWidgets('Home resumes a stored chapter without marking it completed',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = await tester.runAsync(() async {
      await database.visit('JHN.3');
      return database.load();
    });
    await tester.pumpWidget(
        SelahApp(initialBible: bible, database: database, initialData: data));
    expect(find.text('Juan 3'), findsWidgets);
    await tester.scrollUntilVisible(
        find.text('0 of 1,189 chapters marked as read'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('0 of 1,189 chapters marked as read'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Continue Reading'), -200,
        scrollable: find.byType(Scrollable).first);
    await tapAndSave(tester, find.text('Continue Reading'));
    expect(find.byKey(const ValueKey('verse-JHN.3.1')), findsOneWidget);
    await tester.runAsync(() => tester.ensureVisible(
        find.byKey(const ValueKey('chapter-completion-action'))));
    await tester.pumpAndSettle();
    await tapAndSave(
        tester, find.byKey(const ValueKey('chapter-completion-action')));
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('1 of 1,189 chapters marked as read'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('1 of 1,189 chapters marked as read'), findsOneWidget);
  });

  testWidgets('Note editor fits a phone keyboard and saves the reflection',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(SelahApp(
        initialBible: bible,
        database: database,
        initialData: const UserData()));
    await tapAndSave(tester, find.text('Continue Reading'));
    await tester.tap(find.byKey(const ValueKey('verse-GEN.1.1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Write a reflection'));
    await tester.pumpAndSettle();
    expect(find.text('Write a note'), findsOneWidget);
    expect(find.text('Genesis 1:1 · OCCB'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'A moment of gratitude.');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tapAndSave(tester, find.text('Save note'));
    expect(find.text('Write a note'), findsNothing);
    final data = await tester.runAsync(database.load);
    expect(data!.notes['GEN.1.1'], 'A moment of gratitude.');
    expect(find.textContaining('Reflection:'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('verse-note-GEN.1.1')));
    await tester.pumpAndSettle();
    expect(find.text('Edit your note'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'A moment of gratitude.');
  });

  testWidgets('Search opens the matching verse and retains the query on return',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(SelahApp(
        initialBible: bible,
        database: database,
        initialData: const UserData()));
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Juan 3:16');
    await tester.pumpAndSettle();
    final result = find.byKey(const ValueKey('result-JHN.3.16'));
    await tester.ensureVisible(result);
    await tester.pumpAndSettle();
    await tapAndSave(tester, result);
    final verse = find.byKey(const ValueKey('verse-JHN.3.16'));
    expect(verse, findsOneWidget);
    expect(
        tester.getRect(verse).overlaps(const Rect.fromLTWH(0, 56, 1280, 944)),
        isTrue);
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Juan 3:16');
    expect(result, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
