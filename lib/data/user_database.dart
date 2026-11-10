import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'dart:convert';
import 'growth_entry.dart';

class ReadingEntry {
  final String reference;
  final DateTime visitedAt;
  final bool completed;
  const ReadingEntry(this.reference, this.visitedAt, this.completed);
}

class UserData {
  final Map<String, String> preferences;
  final Set<String> bookmarks;
  final Map<String, String> notes;
  final Map<String, int> highlights;
  final List<ReadingEntry> history;
  final Map<String, String> noteTranslations;
  final List<GrowthEntry> growth;
  const UserData(
      {this.preferences = const {},
      this.bookmarks = const {},
      this.notes = const {},
      this.highlights = const {},
      this.history = const [],
      this.noteTranslations = const {},
      this.growth = const []});
}

/// Explicit SQL schema managed by Drift. User content is separate from Scripture.
/// Schema changes must bump schemaVersion and supply a non-destructive migration.
class UserDatabase extends GeneratedDatabase {
  UserDatabase(super.executor);

  factory UserDatabase.local() => UserDatabase(driftDatabase(
        name: 'selah_user',
        web: DriftWebOptions(
          sqlite3Wasm: Uri.parse('sqlite3.wasm'),
          driftWorker: Uri.parse('drift_worker.js'),
          onResult: (result) {
            if (result.chosenImplementation ==
                WasmStorageImplementation.inMemory) {
              throw StateError('Persistent browser storage is unavailable.');
            }
          },
        ),
      ));

  @override
  int get schemaVersion => 6;
  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];
  @override
  Iterable<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(onCreate: (_) async {
        await customStatement(
            'CREATE TABLE preferences (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
        await customStatement('''CREATE TABLE annotations (
      reference TEXT PRIMARY KEY,
      bookmarked INTEGER NOT NULL DEFAULT 0 CHECK(bookmarked IN (0, 1)),
      note TEXT,
      highlight INTEGER,
      source_translation TEXT NOT NULL DEFAULT 'cebocb'
    )''');
        await customStatement('''CREATE TABLE reading (
      reference TEXT PRIMARY KEY,
      visited_at INTEGER NOT NULL,
      completed INTEGER NOT NULL DEFAULT 0 CHECK(completed IN (0, 1))
    )''');
        await createTranslations();
        await createDailyVerseCache();
        await createGrowth();
        await createAssessments();
        await createCommentaryCache();
      }, onUpgrade: (migrator, from, to) async {
        if (from < 2) await createTranslations();
        if (from < 3) await createDailyVerseCache();
        if (from < 4) await createGrowth();
        if (from < 5) await createAssessments();
        if (from < 6) await createCommentaryCache();
      });

  Future<void> createAssessments() => customStatement(
      'CREATE TABLE IF NOT EXISTS assessment_attempts (id TEXT PRIMARY KEY, content TEXT NOT NULL)');

  Future<void> createCommentaryCache() => customStatement('''
    CREATE TABLE IF NOT EXISTS commentary_cache (
      reference TEXT PRIMARY KEY, content TEXT NOT NULL, accessed_at INTEGER NOT NULL
    )''');

  Future<void> createGrowth() async {
    await customStatement(
        'CREATE TABLE growth_entries (id TEXT PRIMARY KEY, content TEXT NOT NULL)');
    await customStatement(
        'CREATE TABLE growth_seen (card_id TEXT PRIMARY KEY, seen_at INTEGER NOT NULL)');
  }

  Future<List<GrowthEntry>> growthEntries() async => [
        for (final row
            in await customSelect('SELECT content FROM growth_entries').get())
          GrowthEntry.fromJson(
              jsonDecode(row.read<String>('content')) as Map<String, dynamic>)
      ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Future<void> saveGrowth(GrowthEntry entry) => customStatement(
      'INSERT INTO growth_entries (id, content) VALUES (?, ?) ON CONFLICT(id) DO UPDATE SET content=excluded.content',
      [entry.id, jsonEncode(entry.toJson())]);
  Future<void> deleteGrowth(String id) =>
      customStatement('DELETE FROM growth_entries WHERE id = ?', [id]);
  Future<Map<String, DateTime>> growthSeen() async => {
        for (final row in await customSelect('SELECT * FROM growth_seen').get())
          row.read<String>('card_id'):
              DateTime.fromMillisecondsSinceEpoch(row.read<int>('seen_at'))
      };
  Future<void> markGrowthSeen(String id) => customStatement(
      'INSERT INTO growth_seen (card_id, seen_at) VALUES (?, ?) ON CONFLICT(card_id) DO UPDATE SET seen_at=excluded.seen_at',
      [id, DateTime.now().millisecondsSinceEpoch]);

  Future<void> createDailyVerseCache() =>
      customStatement('''CREATE TABLE daily_verse_cache (
    day TEXT PRIMARY KEY, reference TEXT NOT NULL,
    online INTEGER NOT NULL CHECK(online IN (0, 1))
  )''');

  Future<({String reference, bool online})?> dailyVerse(String day) async {
    final row = await customSelect(
        'SELECT reference, online FROM daily_verse_cache WHERE day = ?',
        variables: [Variable(day)]).getSingleOrNull();
    return row == null
        ? null
        : (
            reference: row.read<String>('reference'),
            online: row.read<int>('online') == 1
          );
  }

  Future<void> cacheDailyVerse(String day, String reference, bool online) =>
      transaction(() async {
        await customStatement(
            'DELETE FROM daily_verse_cache WHERE day <> ?', [day]);
        await customStatement(
            'INSERT INTO daily_verse_cache (day, reference, online) VALUES (?, ?, ?) ON CONFLICT(day) DO UPDATE SET reference=excluded.reference, online=excluded.online',
            [day, reference, online ? 1 : 0]);
      });

  Future<void> createTranslations() =>
      customStatement('''CREATE TABLE translations (
    id TEXT PRIMARY KEY, content TEXT NOT NULL, checksum TEXT NOT NULL,
    installed_at INTEGER NOT NULL
  )''');

  Future<Map<String, String>> installedTranslations() async => {
        for (final row
            in await customSelect('SELECT id FROM translations').get())
          row.read<String>('id'): row.read<String>('id')
      };

  Future<({String content, String checksum})?> translation(String id) async {
    final row = await customSelect(
        'SELECT content, checksum FROM translations WHERE id = ?',
        variables: [Variable(id)]).getSingleOrNull();
    return row == null
        ? null
        : (
            content: row.read<String>('content'),
            checksum: row.read<String>('checksum')
          );
  }

  Future<void> installTranslation(String id, String content, String checksum) =>
      customStatement(
          'INSERT INTO translations (id, content, checksum, installed_at) VALUES (?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET content=excluded.content, checksum=excluded.checksum, installed_at=excluded.installed_at',
          [id, content, checksum, DateTime.now().millisecondsSinceEpoch]);

  Future<void> removeTranslation(String id) => transaction(() async {
        if (id == 'cebocb') {
          throw StateError('The bundled Bible cannot be removed.');
        }
        await customStatement('DELETE FROM translations WHERE id = ?', [id]);
        await customStatement(
            "UPDATE preferences SET value = 'cebocb' WHERE key = 'translation' AND value = ?",
            [id]);
      });

  Future<UserData> load() => transaction(() async {
        final preferences =
            await customSelect('SELECT * FROM preferences').get();
        final annotations =
            await customSelect('SELECT * FROM annotations').get();
        final reading = await customSelect(
                'SELECT * FROM reading ORDER BY visited_at DESC, reference')
            .get();
        return UserData(
          growth: await growthEntries(),
          preferences: {
            for (final row in preferences)
              row.read<String>('key'): row.read<String>('value')
          },
          bookmarks: {
            for (final row in annotations)
              if (row.read<int>('bookmarked') == 1)
                row.read<String>('reference')
          },
          notes: {
            for (final row in annotations)
              if (row.readNullable<String>('note') != null)
                row.read<String>('reference'): row.read<String>('note')
          },
          noteTranslations: {
            for (final row in annotations)
              if (row.readNullable<String>('note') != null)
                row.read<String>('reference'):
                    row.read<String>('source_translation')
          },
          highlights: {
            for (final row in annotations)
              if (row.readNullable<int>('highlight') != null)
                row.read<String>('reference'): row.read<int>('highlight')
          },
          history: [
            for (final row in reading)
              ReadingEntry(
                  row.read<String>('reference'),
                  DateTime.fromMillisecondsSinceEpoch(
                      row.read<int>('visited_at')),
                  row.read<int>('completed') == 1)
          ],
        );
      });

  Future<void> setPreferences(Map<String, String> values) =>
      transaction(() async {
        for (final entry in values.entries) {
          await customStatement(
              'INSERT INTO preferences (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value=excluded.value',
              [entry.key, entry.value]);
        }
      });

  Future<void> setBookmark(String reference, bool bookmarked) => customStatement(
      'INSERT INTO annotations (reference, bookmarked) VALUES (?, ?) ON CONFLICT(reference) DO UPDATE SET bookmarked=excluded.bookmarked',
      [reference, bookmarked ? 1 : 0]);

  Future<void> setNote(String reference, String? note,
          {String sourceTranslation = 'cebocb'}) =>
      customStatement(
          'INSERT INTO annotations (reference, note, source_translation) VALUES (?, ?, ?) ON CONFLICT(reference) DO UPDATE SET note=excluded.note, source_translation=CASE WHEN annotations.note IS NULL THEN excluded.source_translation ELSE annotations.source_translation END',
          [reference, note, sourceTranslation]);

  Future<void> setHighlight(String reference, int? color) => customStatement(
      'INSERT INTO annotations (reference, highlight) VALUES (?, ?) ON CONFLICT(reference) DO UPDATE SET highlight=excluded.highlight',
      [reference, color]);

  Future<void> visit(String reference, {double offset = 0}) =>
      transaction(() async {
        await customStatement(
            'INSERT INTO reading (reference, visited_at) VALUES (?, ?) ON CONFLICT(reference) DO UPDATE SET visited_at=excluded.visited_at',
            [reference, DateTime.now().millisecondsSinceEpoch]);
        await setPreferences(
            {'lastChapter': reference, 'scrollOffset': '$offset'});
      });

  Future<void> setCompleted(String reference, bool completed) => customStatement(
      'INSERT INTO reading (reference, visited_at, completed) VALUES (?, ?, ?) ON CONFLICT(reference) DO UPDATE SET completed=excluded.completed',
      [reference, DateTime.now().millisecondsSinceEpoch, completed ? 1 : 0]);
}
