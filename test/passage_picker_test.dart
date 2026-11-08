import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/data/bible.dart';
import 'package:selah/data/book_categories.dart';
import 'package:selah/features/reader/passage_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Bible bible;
  setUpAll(() async => bible = await Bible.load());

  test('Categories cover all 66 books exactly once across both testaments', () {
    final ids = bookCategories.expand((category) => category.books).toList();
    expect(ids.length, 66);
    expect(ids.toSet(), bible.books.map((book) => book.id).toSet());
    expect(
        bookCategories
            .where((category) => category.oldTestament)
            .expand((category) => category.books)
            .length,
        39);
    expect(
        bookCategories
            .where((category) => !category.oldTestament)
            .expand((category) => category.books)
            .length,
        27);
  });

  testWidgets('Books opens at the current book and returns a chosen chapter',
      (tester) async {
    PassageSelection? selection;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () async {
                        selection = await Navigator.of(context)
                            .push<PassageSelection>(MaterialPageRoute(
                                builder: (_) => PassagePicker(
                                    bible: bible,
                                    currentBook: 42,
                                    currentChapter: 2)));
                      },
                      child: const Text('Open picker')),
                ))));
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    final current = find.byKey(const ValueKey('pick-book-JHN'));
    expect(current.hitTestable(), findsOneWidget);
    expect(tester.widget<ListTile>(current).selected, isTrue);
    expect(find.text('Gospels'), findsOneWidget);
    await tester.tap(current);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pick-chapter-16')));
    await tester.pumpAndSettle();
    expect(selection!.book, 42);
    expect(selection!.chapter, 15);
    expect(find.text('Open picker'), findsOneWidget);
  });

  for (final book in [0, 42]) {
    testWidgets(
        'Returning from chapters after scrolling keeps Books usable ($book)',
        (tester) async {
      tester.view.physicalSize = const Size(600, 560);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          home: PassagePicker(
              bible: bible, currentBook: book, currentChapter: 0)));
      await tester.pumpAndSettle();
      final target =
          find.byKey(ValueKey('pick-book-${book == 0 ? 'DEU' : 'JHN'}'));
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      for (var visit = 0; visit < 2; visit++) {
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(find.text('Choose a chapter'), findsOneWidget);
        await tester.tap(find.byTooltip('Back to books'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Books'), findsOneWidget);
        expect(target.hitTestable(), findsOneWidget);
      }
      await tester
          .tap(find.text(book == 0 ? 'New Testament' : 'Old Testament'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Find a book'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'John');
      await tester.pumpAndSettle();
      final john = find.byKey(const ValueKey('pick-book-JHN'));
      await tester.ensureVisible(john);
      await tester.tap(john);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back to books'));
      await tester.pumpAndSettle();
      expect(john.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
