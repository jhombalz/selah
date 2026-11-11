import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:selah/data/bible.dart';
import 'package:selah/data/reading_format.dart';
import 'package:selah/data/translations.dart';
import 'package:selah/data/user_database.dart';
import 'package:selah/features/reader/passage_paragraph.dart';
import 'package:selah/features/reader/passage_selection_layer.dart';
import 'package:selah/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Bible bundled, bsb, kjv;
  setUpAll(() async {
    bundled = await Bible.load();
    Future<Bible> edition(String id) async {
      final bytes = await File('web/translations/$id.zip').readAsBytes();
      return TranslationDownloader(
              clientFactory: () =>
                  MockClient((_) async => http.Response.bytes(bytes, 200)))
          .download(translationCatalog.firstWhere((s) => s.id == id), bundled,
              (_, __) {});
    }

    bsb = await edition('bsb');
    kjv = await edition('kjv');
  });

  test(
      'Offline metadata preserves wording and supplies edition-specific formatting',
      () async {
    expect(bundled.verse('LUK.6.1').readingFormat!.headings.first,
        contains('Igpapahulay'));
    expect(bundled.verse('GEN.1.17-18').readingFormat, isNotNull);
    final format = bsb.verse('LUK.6.1').readingFormat!;
    expect(format.headings, ['The Lord of the Sabbath']);
    expect(format.crossReferences,
        ['1 Samuel 21:1–7', 'Matthew 12:1–8', 'Mark 2:23–28']);
    expect(format.notes.single, contains('second Sabbath'));
    expect(
        bsb.verse('LUK.6.3').readingFormat!.segments.any((s) => s.wordsOfJesus),
        isFalse);
    final jesus = kjv.verse('LUK.6.3').readingFormat!.segments;
    expect(jesus.first.wordsOfJesus, isFalse);
    expect(jesus.where((s) => s.wordsOfJesus).map((s) => s.text).join(),
        contains('Have ye not read'));
    expect(
        kjv
            .verse('GEN.1.2')
            .readingFormat!
            .segments
            .where((s) => s.italic)
            .map((s) => s.text)
            .join(),
        contains('was'));
    final entries = await ReadingFormat.load('kjv');
    expect(ReadingFormat.match(entries, 'LUK.6', '3', 'A different edition'),
        isNull);
    for (final bible in [bundled, bsb, kjv]) {
      int total = 0, matched = 0;
      for (final book in bible.books) {
        for (final chapter in book.chapters) {
          for (final verse in chapter) {
            total++;
            if (verse.readingFormat case final presentation?) {
              matched++;
              expect(
                  ReadingFormat.normalized(
                      presentation.segments.map((s) => s.text).join()),
                  ReadingFormat.normalized(bible.id == 'kjv'
                      ? verse.text.replaceAll(RegExp(r'[\[\]]'), '')
                      : verse.text));
            }
          }
        }
      }
      expect(matched / total, greaterThan(.90),
          reason: '${bible.id} source match coverage');
      final restored =
          await Bible.withReadingFormat(Bible.fromJson(bible.toJson()));
      expect(restored.verse('LUK.6.3').text, bible.verse('LUK.6.3').text);
      expect(restored.verse('LUK.6.3').readingFormat, isNotNull);
    }
  });

  testWidgets('Paragraphs retain precise tap and drag selection across verses',
      (tester) async {
    final geometry = ParagraphGeometry(), anchors = <String, GlobalKey>{};
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    String? tapped, selected;
    final verses =
        bsb.books.firstWhere((b) => b.id == 'LUK').chapters[5].take(2).toList();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 600,
                child: PassageSelectionLayer(
                    scrollController: scroll,
                    references: ['LUK.6.1', 'LUK.6.2'],
                    anchors: anchors,
                    hitTestVerse: geometry.hit,
                    onChanged: (_) {},
                    onFinished: (value) => selected = value,
                    child: SingleChildScrollView(
                        controller: scroll,
                        child: PassageParagraph(
                            verses: verses,
                            prefix: 'LUK.6',
                            fontSize: 22,
                            redLetters: true,
                            anchors: anchors,
                            geometry: geometry,
                            background: (_) => null,
                            onVerse: (value) => tapped = value,
                            indicators: (_, __) => [])))))));
    Offset point(String reference) {
      final range = geometry.ranges[reference]!;
      final render =
          range.key.currentContext!.findRenderObject()! as RenderParagraph;
      final boxes = render.getBoxesForSelection(
          TextSelection(baseOffset: range.start, extentOffset: range.end));
      return render.localToGlobal(boxes.first.toRect().center);
    }

    await tester.tapAt(point('LUK.6.2'));
    await tester.pump();
    expect(tapped, 'LUK.6.2');
    final gesture = await tester.startGesture(point('LUK.6.1'));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(point('LUK.6.2'));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(selected, 'LUK.6.1-2');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'Desktop has edge arrows, source footnotes and clickable section references',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = UserDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(SelahApp(
        initialBible: bsb,
        database: db,
        initialData: const UserData(preferences: {'lastChapter': 'LUK.6'})));
    await tester.tap(find.text('Continue Reading'));
    await tester.pumpAndSettle();
    expect(find.text('The Lord of the Sabbath'), findsOneWidget);
    expect(
        tester.getCenter(find.byTooltip('Previous chapter')).dx, lessThan(200));
    expect(
        tester.getCenter(find.byTooltip('Next chapter')).dx, greaterThan(1300));
    await tester
        .tap(find.byKey(const ValueKey('translation-footnotes-LUK.6.1')));
    await tester.pumpAndSettle();
    expect(find.text('BYZ and TR On the second Sabbath after the first'),
        findsOneWidget);
    await tester.tap(find.byTooltip('Close dialog').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matthew 12:1–8'));
    await tester.pumpAndSettle();
    expect(find.text('Matthew 12'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'Phone reading preferences fit large text and persist layout choices',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final db = UserDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(SelahApp(
        initialBible: kjv,
        database: db,
        initialData: const UserData(preferences: {'lastChapter': 'LUK.6'})));
    await tester.tap(find.text('Bible'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('text-size')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Paragraph reading'));
    await tester.tap(find.widgetWithText(SwitchListTile, 'Paragraph reading'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close text size'));
    await tester.pumpAndSettle();
    expect(find.text('Reading preferences'), findsNothing);
    expect(find.byType(PassageParagraph), findsWidgets);
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect((await tester.runAsync(() => db.load()))!.preferences['paragraphs'],
        'true');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
