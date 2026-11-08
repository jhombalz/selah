import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:selah/data/bible.dart';
import 'package:selah/data/bible_search.dart';
import 'package:selah/data/translations.dart';
import 'package:selah/data/user_database.dart';
import 'package:selah/data/user_backup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Bible bundled;
  setUpAll(() async => bundled = await Bible.load());

  for (final spec in translationCatalog.where((spec) => spec.id != 'cebocb')) {
    test(
        '${spec.abbreviation} package passes integrity and complete-canon validation',
        () async {
      final bytes = await File('web/translations/${spec.id}.zip').readAsBytes();
      final downloader = TranslationDownloader(
          clientFactory: () =>
              MockClient((_) async => http.Response.bytes(bytes, 200)));
      final bible = await downloader.download(spec, bundled, (_, __) {});
      expect(bible.id, spec.id);
      expect((await BibleSearch(bible).search('Juan 3:16')).hits.single.key,
          'JHN.3.16');
      expect(bible.books.length, 66);
      expect(
          bible.books.fold<int>(0, (sum, book) => sum + book.chapters.length),
          1189);
      expect(bible.verse('JHN.3.16').text.toLowerCase(),
          contains(spec.language == 'Tagalog' ? 'diyos' : 'god so loved'));
      expect(bible.verse('GEN.1.17-18').text,
          contains(bible.verse('GEN.1.18').text));
      expect(bible.licenseText,
          contains(spec.id == 'tglulb' ? 'CC BY-SA 4.0' : 'Public Domain'));
      if (spec.id == 'tglulb') {
        expect(bible.licenseText, contains('Abantes'));
      }
      final directory =
          await Directory.systemTemp.createTemp('selah-translation-');
      final file = File('${directory.path}/bible.sqlite');
      var database = UserDatabase(NativeDatabase(file));
      try {
        final content = jsonEncode(bible.toJson());
        await database.installTranslation(
            spec.id, content, sha256.convert(utf8.encode(content)).toString());
        await database.close();
        database = UserDatabase(NativeDatabase(file));
        final installed = await loadInstalledBible(database, spec.id);
        expect(installed!.verse('JHN.3.16').text, bible.verse('JHN.3.16').text);
        await database.setBookmark('GEN.1.17-18', true);
        await database.setNote('GEN.1.17-18', 'My reflection',
            sourceTranslation: spec.id);
        await database.setPreferences({'translation': spec.id});
        final backup = await BackupService(database, bundled).capture();
        await database.setNote('GEN.1.17-18', 'Changed');
        final restored = await BackupService(database, bundled).restore(
            UserBackup.decode(backup.encode(), bundled), RestoreMode.replace);
        expect(restored.translationFallback, isFalse);
        expect(restored.data.preferences['translation'], spec.id);
        expect(restored.data.noteTranslations['GEN.1.17-18'], spec.id);
        expect(restored.data.notes['GEN.1.17-18'], 'My reflection');
        await database.removeTranslation(spec.id);
        final user = await database.load();
        expect(user.bookmarks, contains('GEN.1.17-18'));
        expect(user.notes['GEN.1.17-18'], 'My reflection');
        expect(user.noteTranslations['GEN.1.17-18'], spec.id);
        expect(user.preferences['translation'], 'cebocb');
        expect(await database.translation(spec.id), isNull);
      } finally {
        await database.close();
        await directory.delete(recursive: true);
      }
    });
  }

  test('Failed and cancelled downloads do not produce an installable Bible',
      () async {
    final spec = translationCatalog[1];
    final failed = TranslationDownloader(
        clientFactory: () =>
            MockClient((_) async => http.Response('Unavailable', 503)));
    await expectLater(
        failed.download(spec, bundled, (_, __) {}), throwsStateError);
    final invalid = TranslationDownloader(
        clientFactory: () =>
            MockClient((_) async => http.Response('Not a ZIP package', 200)));
    await expectLater(
        invalid.download(spec, bundled, (_, __) {}), throwsA(isA<Exception>()));
    final bytes = await File('web/translations/web.zip').readAsBytes();
    final cancelled = TranslationDownloader(
        clientFactory: () =>
            MockClient((_) async => http.Response.bytes(bytes, 200)));
    await expectLater(
        cancelled.download(spec, bundled, (_, __) => cancelled.cancel()),
        throwsA(isA<DownloadCancelled>()));
  });

  test(
      'Wrong edition package and corrupted storage are rejected without losing notes',
      () async {
    final spec = translationCatalog.firstWhere((s) => s.id == 'bsb');
    final wrongPackage = await File('web/translations/web.zip').readAsBytes();
    final downloader = TranslationDownloader(
        clientFactory: () =>
            MockClient((_) async => http.Response.bytes(wrongPackage, 200)));
    await expectLater(
        downloader.download(spec, bundled, (_, __) {}), throwsFormatException);
    final db = UserDatabase(NativeDatabase.memory());
    try {
      await db.setNote('JHN.3.16', 'Keep this reflection',
          sourceTranslation: 'tglulb');
      await db.installTranslation(
          'bsb', '{"damaged":true}', 'invalid-checksum');
      await expectLater(loadInstalledBible(db, 'bsb'), throwsFormatException);
      final data = await db.load();
      expect(data.notes['JHN.3.16'], 'Keep this reflection');
      expect(data.noteTranslations['JHN.3.16'], 'tglulb');
    } finally {
      await db.close();
    }
  });

  test('Combined references overlap without leaking across chapters or books',
      () {
    expect(Bible.overlaps('GEN.1.17-18', 'GEN.1.18'), isTrue);
    expect(Bible.overlaps('GEN.1.17-18', 'GEN.1.19'), isFalse);
    expect(Bible.overlaps('GEN.1.17-18', 'GEN.2.18'), isFalse);
    expect(Bible.overlaps('GEN.1.17-18', 'EXO.1.18'), isFalse);
  });

  for (final version in [1, 2]) {
    test(
        'Schema upgrade from $version preserves user data and note creation edition',
        () async {
      final directory =
          await Directory.systemTemp.createTemp('selah-migration-');
      final file = File('${directory.path}/data.sqlite');
      var database = UserDatabase(NativeDatabase(file));
      try {
        await database.setNote('JHN.3.16', 'Original note');
        await database.setBookmark('JHN.3.16', true);
        if (version == 1) {
          await database.customStatement('DROP TABLE translations');
        }
        await database.customStatement('DROP TABLE daily_verse_cache');
        await database.customStatement('PRAGMA user_version = $version');
        await database.close();
        database = UserDatabase(NativeDatabase(file));
        expect(await database.installedTranslations(), isEmpty);
        await database.setNote('JHN.3.16', 'Edited in WEB',
            sourceTranslation: 'web');
        final user = await database.load();
        expect(user.notes['JHN.3.16'], 'Edited in WEB');
        expect(user.noteTranslations['JHN.3.16'], 'cebocb');
        expect(user.bookmarks, contains('JHN.3.16'));
        await expectLater(
            database.removeTranslation('cebocb'), throwsStateError);
      } finally {
        await database.close();
        await directory.delete(recursive: true);
      }
    });
  }
}
