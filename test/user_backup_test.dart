import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/data/bible.dart';
import 'package:selah/data/user_backup.dart';
import 'package:selah/data/user_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Bible canon;
  late UserDatabase database;
  setUpAll(() async => canon = await Bible.load());
  setUp(() => database = UserDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  UserBackup fixture() => UserBackup.create(
      UserData(
        preferences: const {
          'dark': 'true',
          'audioFollow': 'false',
          'fontSize': '28',
          'translation': 'asv',
          'lastChapter': 'GEN.1',
          'scrollOffset': '240'
        },
        bookmarks: const {'GEN.1.1-3'},
        notes: const {
          'GEN.1.1': 'Salamat, Ginoo! “Kahayag”\nA personal reflection.',
          'GEN.1.2': 'Another note'
        },
        noteTranslations: const {'GEN.1.1': 'web', 'GEN.1.2': 'cebocb'},
        highlights: const {'GEN.1.1-10': 0xffffc107},
        history: [ReadingEntry('GEN.1', DateTime.utc(2026, 10, 1), true)],
      ),
      canon,
      createdAt: DateTime.utc(2026, 11, 7));

  Uint8List changed(
      UserBackup backup, void Function(Map<String, dynamic>) edit) {
    final root =
        jsonDecode(utf8.decode(backup.encode())) as Map<String, dynamic>;
    edit(root);
    root['checksum'] =
        sha256.convert(utf8.encode(jsonEncode(root['payload']))).toString();
    return Uint8List.fromList(utf8.encode(jsonEncode(root)));
  }

  test('Backup round trip preserves Unicode, ranges, settings and provenance',
      () {
    final original = fixture();
    final decoded = UserBackup.decode(original.encode(), canon);
    expect(decoded.data.notes, original.data.notes);
    expect(decoded.data.noteTranslations, original.data.noteTranslations);
    expect(decoded.data.bookmarks, original.data.bookmarks);
    expect(decoded.data.highlights, original.data.highlights);
    expect(decoded.data.preferences, original.data.preferences);
    expect(decoded.data.history.single.completed, isTrue);
    expect(decoded.createdAt, DateTime.utc(2026, 11, 7));
    final data = (jsonDecode(utf8.decode(original.encode())) as Map)['payload']
        ['data'] as Map;
    expect(data.keys.toSet(), {'preferences', 'annotations', 'history'});
  });

  test('Invalid, unsupported, altered and oversized files are rejected', () {
    final backup = fixture();
    expect(() => UserBackup.decode(utf8.encode('{broken'), canon),
        throwsFormatException);
    expect(() => UserBackup.decode(Uint8List(UserBackup.maxBytes + 1), canon),
        throwsFormatException);
    final altered =
        jsonDecode(utf8.decode(backup.encode())) as Map<String, dynamic>;
    altered['payload']['data']['preferences']['dark'] = 'false';
    expect(() => UserBackup.decode(utf8.encode(jsonEncode(altered)), canon),
        throwsFormatException);
    expect(
        () => UserBackup.decode(
            changed(backup, (root) => root['version'] = 99), canon),
        throwsFormatException);
    expect(
        () => UserBackup.decode(
            changed(
                backup,
                (root) =>
                    root['payload']['data']['preferences']['fontSize'] = 'NaN'),
            canon),
        throwsFormatException);
    expect(
        () => UserBackup.decode(
            changed(
                backup,
                (root) => root['payload']['data']['annotations'][0]
                    ['reference'] = 'GEN.1.999'),
            canon),
        throwsFormatException);
    expect(
        () => UserBackup.decode(
            changed(
                backup,
                (root) => root['payload']['data']['annotations'][0]
                    ['reference'] = 'BAD.1.1'),
            canon),
        throwsFormatException);
    expect(
        () => UserBackup.decode(
            changed(
                backup,
                (root) => root['payload']['data']['annotations'][0]
                    ['highlight'] = -1),
            canon),
        throwsFormatException);
  });

  test('Merge keeps local conflicts, combines progress and is idempotent',
      () async {
    await database.setNote('GEN.1.1', 'Keep local', sourceTranslation: 'asv');
    await database.setHighlight('GEN.1.3-4', 0xff2196f3);
    await database.setPreferences({'fontSize': '20', 'translation': 'cebocb'});
    await database.visit('GEN.1');
    final service = BackupService(database, canon);
    final result = await service.restore(fixture(), RestoreMode.merge);
    expect(result.data.notes['GEN.1.1'], 'Keep local');
    expect(result.data.notes['GEN.1.2'], 'Another note');
    expect(result.data.noteTranslations['GEN.1.1'], 'asv');
    expect(result.data.preferences['fontSize'], '20');
    expect(result.data.history.single.completed, isTrue);
    expect(result.data.highlights, {
      'GEN.1.1-2': 0xffffc107,
      'GEN.1.3-4': 0xff2196f3,
      'GEN.1.5-10': 0xffffc107
    });
    final again = await service.restore(fixture(), RestoreMode.merge);
    expect(again.data.notes, result.data.notes);
    expect(again.data.bookmarks, result.data.bookmarks);
    expect(again.data.highlights, result.data.highlights);
  });

  test(
      'Replace removes absent user data, keeps downloads and handles unavailable editions',
      () async {
    await database.setNote('JHN.3.16', 'Replace this');
    await database.installTranslation(
        'web', 'Downloaded Bible content stays', 'checksum');
    final result = await BackupService(database, canon)
        .restore(fixture(), RestoreMode.replace);
    expect(result.data.notes.containsKey('JHN.3.16'), isFalse);
    expect(result.data.notes['GEN.1.1'], contains('Salamat'));
    expect(result.data.noteTranslations['GEN.1.1'], 'web');
    expect(result.translationFallback, isTrue);
    expect(result.data.preferences['translation'], 'cebocb');
    expect(result.data.preferences['scrollOffset'], '0');
    expect((await database.translation('web'))!.content,
        'Downloaded Bible content stays');
  });

  test(
      'A failed restore rolls back deletions, preferences and inserted records',
      () async {
    await database.setNote('JHN.3.16', 'Must survive');
    await database.setPreferences({'fontSize': '21'});
    await database.customStatement(
        "CREATE TRIGGER reject_restore BEFORE INSERT ON annotations WHEN NEW.reference = 'GEN.1.2' BEGIN SELECT RAISE(ABORT, 'test failure'); END");
    await expectLater(
        BackupService(database, canon).restore(fixture(), RestoreMode.replace),
        throwsA(isA<Exception>()));
    final current = await database.load();
    expect(current.notes, {'JHN.3.16': 'Must survive'});
    expect(current.preferences, {'fontSize': '21'});
    expect(current.bookmarks, isEmpty);
  });

  test('Export captures user data without downloaded Bible content', () async {
    await database.setNote('GEN.1.1-3', 'My range note');
    await database.setBookmark('GEN.1.1-3', true);
    await database.installTranslation(
        'web', 'Download payload must not enter backup', 'checksum');
    final snapshot = await BackupService(database, canon).capture();
    expect(snapshot.data.notes['GEN.1.1-3'], 'My range note');
    expect(utf8.decode(snapshot.encode()), isNot(contains('Download payload')));
  });
}
