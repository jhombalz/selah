import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:selah/data/bible.dart';
import 'package:selah/data/translations.dart';
import 'package:selah/data/user_database.dart';
import 'package:selah/features/translations/translations_page.dart';
import 'package:selah/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Bible bundled, bsb;
  setUpAll(() async {
    bundled = await Bible.load();
    final bytes = await File('web/translations/bsb.zip').readAsBytes();
    bsb = await TranslationDownloader(
        clientFactory: () =>
            MockClient((_) async => http.Response.bytes(bytes, 200))).download(
        translationCatalog.firstWhere((s) => s.id == 'bsb'),
        bundled,
        (_, __) {});
  });

  for (final size in [
    const Size(320, 640),
    const Size(768, 1024),
    const Size(1440, 900)
  ]) {
    testWidgets('Home, reader and translation cards fit $size with large text',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final db = UserDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.pumpWidget(SelahApp(
          initialBible: bsb,
          database: db,
          initialData:
              const UserData(preferences: {'dark': 'true', 'fontSize': '32'})));
      await tester.scrollUntilVisible(find.text('VERSE OF THE DAY'), 150);
      expect(find.text('VERSE OF THE DAY'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Continue Reading'), -150);
      await tester.ensureVisible(find.text('Continue Reading'));
      await tester.tap(find.text('Continue Reading'));
      await tester.pumpAndSettle();
      expect(
          find.byTooltip('Play BSB audio · Internet required'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(MaterialApp(
          home: TranslationsPage(
              database: db,
              bundled: bundled,
              activeId: 'cebocb',
              onSelect: (_) async {},
              onRemove: (_) async {})));
      await tester.runAsync(() => db.load());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Download ULB'), 200);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
