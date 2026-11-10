import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/data/bible.dart';
import 'package:selah/data/growth_entry.dart';
import 'package:selah/data/user_database.dart';
import 'package:selah/data/user_backup.dart';
import 'package:selah/features/growth/growth_catalog.dart';
import 'package:selah/features/growth/growth_page.dart';
import 'package:selah/features/growth/growth_share.dart';
import 'package:selah/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Bible bible;
  late UserDatabase database;
  setUpAll(() async => bible = await Bible.load());
  setUp(() => database = UserDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  GrowthEntry session() => GrowthEntry.create(
      kind: 'session', title: 'A quiet moment', reference: 'PHP.4.4-9');

  test(
      'all themed passages exist and repeat avoidance cycles through each theme',
      () async {
    expect(growthCatalog.length, 15);
    for (final theme in growthThemes) {
      final seen = <String, DateTime>{};
      for (var i = 0; i < 3; i++) {
        final card = chooseGrowthCard(theme, seen);
        expect(seen.containsKey(card.id), isFalse);
        final parts = card.reference.split('.');
        final chapter = bible.books
            .firstWhere((b) => b.id == parts[0])
            .chapters[int.parse(parts[1]) - 1];
        final range = parts[2].split('-').map(int.parse).toList();
        for (var n = range.first; n <= range.last; n++) {
          expect(
              chapter.any((v) => Bible.overlaps('${parts[0]}.${parts[1]}.$n',
                  '${parts[0]}.${parts[1]}.${v.number}')),
              isTrue);
        }
        expect(card.context, isNotEmpty);
        seen[card.id] = DateTime.utc(2026, 1, i + 1);
      }
      expect(chooseGrowthCard(theme, seen).id, seen.keys.first);
    }
  });

  test('prayers, updates and session drafts survive SQLite reopen', () async {
    final directory = await Directory.systemTemp.createTemp('selah-growth-');
    var db =
        UserDatabase(NativeDatabase(File('${directory.path}/journal.sqlite')));
    try {
      final entry = session()
        ..reflection = 'An honest question'
        ..step = 2;
      final prayer = GrowthEntry.create(kind: 'prayer', title: 'For my family')
        ..prayer = 'Help us listen.'
        ..status = 'Still praying'
        ..updateDraft = 'An unfinished update';
      prayer.updates
          .add((date: DateTime.utc(2026, 11, 8), text: 'We talked today.'));
      await db.saveGrowth(entry);
      await db.saveGrowth(prayer);
      await db.close();
      db = UserDatabase(
          NativeDatabase(File('${directory.path}/journal.sqlite')));
      final restored = await db.growthEntries();
      expect(restored.firstWhere((e) => e.id == entry.id).reflection,
          entry.reflection);
      expect(restored.firstWhere((e) => e.id == prayer.id).updates.single.text,
          'We talked today.');
      expect(restored.firstWhere((e) => e.id == prayer.id).updateDraft,
          'An unfinished update');
    } finally {
      await db.close();
      await directory.delete(recursive: true);
    }
  });

  test(
      'journals round trip through backups; merge preserves local conflicts and replace removes absent entries',
      () async {
    final entry = session()
      ..reflection = 'Incoming reflection'
      ..action = 'Encourage a friend'
      ..actionDone = true;
    final incoming = UserBackup.decode(
        UserBackup.create(UserData(growth: [entry]), bible).encode(), bible);
    expect(incoming.data.growth.single.actionDone, isTrue);
    entry.reflection = 'Local reflection';
    await database.saveGrowth(entry);
    final extra = GrowthEntry.create(kind: 'prayer', title: 'Local prayer')
      ..prayer = 'Thank You.';
    await database.saveGrowth(extra);
    final service = BackupService(database, bible);
    await service.restore(incoming, RestoreMode.merge);
    expect(
        (await database.growthEntries())
            .firstWhere((e) => e.id == entry.id)
            .reflection,
        'Local reflection');
    await service.restore(incoming, RestoreMode.replace);
    final records = await database.growthEntries();
    expect(records.length, 1);
    expect(records.single.reflection, 'Incoming reflection');
  });

  test('old backups remain readable and invalid journal records are rejected',
      () {
    final root = jsonDecode(utf8.decode(
        UserBackup.create(const UserData(notes: {'GEN.1.1': 'Kept'}), bible)
            .encode())) as Map<String, dynamic>;
    root['version'] = 1;
    (root['payload']['data'] as Map).remove('growth');
    root['checksum'] =
        sha256.convert(utf8.encode(jsonEncode(root['payload']))).toString();
    final old = UserBackup.decode(utf8.encode(jsonEncode(root)), bible);
    expect(old.data.notes['GEN.1.1'], 'Kept');
    expect(old.data.growth, isEmpty);
    final invalid = session().toJson()..['completed'] = 1;
    expect(() => GrowthEntry.fromJson(invalid), throwsFormatException);
  });

  testWidgets('guided session opens the Bible and returns to reflection',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Future<void> tap(String text) async {
      final finder = find.text(text);
      if (finder.evaluate().isEmpty) {
        await tester.scrollUntilVisible(finder, 300,
            scrollable: find.byType(Scrollable).first);
      }
      await Scrollable.ensureVisible(tester.element(finder), alignment: 0.3);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(finder);
        await database.load();
        await Future<void>.delayed(const Duration(milliseconds: 40));
      });
      await tester.pump();
      await tester.runAsync(() async {
        await database.load();
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(SelahApp(
        initialBible: bible,
        database: database,
        initialData: const UserData()));
    await tap('My time with God');
    await tap('Begin with my current chapter');
    expect(find.text('Pause here.'), findsOneWidget);
    await tap('Read');
    await tap('Open passage in the Bible');
    expect(find.text('Continue reflection'), findsOneWidget);
    final current = (await tester.runAsync(database.growthEntries))!.single;
    current.reflection = 'Updated from my journal';
    await tester.runAsync(() => database.saveGrowth(current));
    await tap('Continue reflection');
    expect(find.widgetWithText(TextField, 'My reflection'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Updated from my journal');
    await tap('Save & close');
    await tester.runAsync(() => database.deleteGrowth(current.id));
    await tap('Continue reflection');
    expect(find.text('Continue reflection'), findsNothing);
    expect(await tester.runAsync(database.growthEntries), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(database.load);
  });

  testWidgets('reflection autosaves and reopens at its saved step',
      (tester) async {
    final entry = session()..step = 2;
    await database.saveGrowth(entry);
    await tester.pumpWidget(MaterialApp(
        home: GrowthEditor(
            database: database, bible: bible, entry: entry, onRead: (_) {})));
    await tester.enterText(
        find.byType(TextField), 'Help me listen with patience.');
    await tester.runAsync(() async {
      await database.load();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    final records = await tester.runAsync(database.growthEntries);
    expect(records!.single.reflection, 'Help me listen with patience.');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(MaterialApp(
        home: GrowthEditor(
            database: database,
            bible: bible,
            entry: records.single,
            onRead: (_) {})));
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Help me listen with patience.');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'sharing keeps private writing unchecked until explicitly selected',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final entry = session()
      ..reflection = 'Private reflection'
      ..prayer = 'Private prayer';
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => previewGrowthShare(context, bible, entry),
                    child: const Text('Preview'))))));
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Private reflection'), findsNothing);
    expect(find.textContaining('Private prayer'), findsNothing);
    await tester.tap(find.text('My reflection'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Private reflection'), findsOneWidget);
    expect(find.textContaining('Private prayer'), findsNothing);
    expect(tester.getRect(find.text('Share')).bottom, lessThan(844));
    expect(tester.takeException(), isNull);
  });
}
