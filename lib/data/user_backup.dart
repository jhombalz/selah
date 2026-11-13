import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'bible.dart';
import 'scripture_range.dart';
import 'user_database.dart';
import 'translations.dart';
import 'growth_entry.dart';

enum RestoreMode { merge, replace }

class UserBackup {
  static const maxBytes = 10 * 1024 * 1024;
  final DateTime createdAt;
  final UserData data;
  const UserBackup._(this.createdAt, this.data);

  factory UserBackup.create(UserData data, Bible canon, {DateTime? createdAt}) {
    final date = (createdAt ?? DateTime.now()).toUtc();
    return UserBackup._(date, _readData(_writeData(data), canon));
  }

  Uint8List encode() {
    final payload = {
      'createdAt': createdAt.toIso8601String(),
      'data': _writeData(data)
    };
    final envelope = {
      'format': 'selah.user-backup',
      'version': 2,
      'payload': payload,
      'checksum': sha256.convert(utf8.encode(jsonEncode(payload))).toString()
    };
    final bytes = Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(envelope)));
    if (bytes.length > maxBytes) {
      throw const FormatException('This backup exceeds the 10 MB limit.');
    }
    return bytes;
  }

  factory UserBackup.decode(List<int> bytes, Bible canon) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('Choose a backup file smaller than 10 MB.');
    }
    final root = _map(
        jsonDecode(utf8.decode(bytes).replaceFirst('\ufeff', '')), 'backup');
    if (root['format'] != 'selah.user-backup') {
      throw const FormatException('This file is not a THE BIBLE user backup.');
    }
    if (root['version'] != 1 && root['version'] != 2) {
      throw const FormatException(
          'This backup version is not supported. Please update the app.');
    }
    final payload = _map(root['payload'], 'backup contents');
    final digest = sha256.convert(utf8.encode(jsonEncode(payload))).toString();
    if (root['checksum'] is! String ||
        (root['checksum'] as String).toLowerCase() != digest) {
      throw const FormatException(
          'The backup is incomplete or has changed since export. Its checksum does not match.');
    }
    final date = _date(payload['createdAt']);
    final rawData = _map(payload['data'], 'user data');
    if (root['version'] == 2 && rawData['growth'] is! List) {
      throw const FormatException(
          'Journal records are missing from this backup.');
    }
    return UserBackup._(date, _readData(rawData, canon));
  }

  static Map<String, dynamic> _writeData(UserData data) {
    final references = {
      ...data.bookmarks,
      ...data.notes.keys,
      ...data.highlights.keys
    }.toList()
      ..sort();
    return {
      'growth': [for (final entry in data.growth) entry.toJson()],
      'preferences': data.preferences,
      'annotations': [
        for (final reference in references)
          {
            'reference': reference,
            'bookmarked': data.bookmarks.contains(reference),
            'note': data.notes[reference],
            'highlight': data.highlights[reference],
            'sourceTranslation': data.noteTranslations[reference] ?? 'cebocb',
          }
      ],
      'history': [
        for (final entry in data.history)
          {
            'reference': entry.reference,
            'visitedAt': entry.visitedAt.toUtc().toIso8601String(),
            'completed': entry.completed
          }
      ],
    };
  }

  static UserData _readData(Map<String, dynamic> raw, Bible canon) {
    final preferences = <String, String>{};
    final rawPreferences = _map(raw['preferences'], 'preferences');
    for (final entry in rawPreferences.entries) {
      if (entry.value is! String || entry.value.length > 128) {
        throw const FormatException('Invalid reading preferences.');
      }
      final value = entry.value as String;
      switch (entry.key) {
        case 'dark':
        case 'audioFollow':
        case 'paragraphs':
        case 'redLetters':
          if (value != 'true' && value != 'false') {
            throw const FormatException('Invalid theme preference.');
          }
        case 'fontSize':
          final number = double.tryParse(value);
          if (number == null ||
              !number.isFinite ||
              number < 16 ||
              number > 32) {
            throw const FormatException('Invalid text size.');
          }
        case 'scrollOffset':
          final number = double.tryParse(value);
          if (number == null ||
              !number.isFinite ||
              number < 0 ||
              number > 10000000) {
            throw const FormatException('Invalid reading position.');
          }
        case 'lastChapter':
        case 'licensedLast_niv':
        case 'licensedLast_nlt':
          _reference(value, canon, chapterOnly: true);
        case 'translation':
        case 'readerTranslation':
          _translation(value);
        default:
          throw const FormatException(
              'The backup contains an unsupported preference.');
      }
      preferences[entry.key] = value;
    }
    final bookmarks = <String>{};
    final notes = <String, String>{};
    final highlights = <String, int>{};
    final sources = <String, String>{};
    final seen = <String>{};
    for (final item in _list(raw['annotations'], 50000)) {
      final row = _map(item, 'annotation');
      final reference = _reference(row['reference'], canon);
      if (!seen.add(reference) || row['bookmarked'] is! bool) {
        throw const FormatException('Invalid or duplicate annotations.');
      }
      if (row['bookmarked'] == true) bookmarks.add(reference);
      final note = row['note'];
      if (note != null && (note is! String || note.length > 1000000)) {
        throw const FormatException('A note is invalid or too large.');
      }
      if (note != null) {
        notes[reference] = note as String;
        sources[reference] = _translation(row['sourceTranslation']);
      }
      final highlight = row['highlight'];
      if (highlight != null &&
          (highlight is! int || highlight < 0 || highlight > 0xffffffff)) {
        throw const FormatException('Invalid highlight color.');
      }
      if (highlight != null) highlights[reference] = highlight as int;
    }
    final history = <ReadingEntry>[];
    final visited = <String>{};
    for (final item in _list(raw['history'], 1189)) {
      final row = _map(item, 'reading history');
      final reference = _reference(row['reference'], canon, chapterOnly: true);
      if (!visited.add(reference) || row['completed'] is! bool) {
        throw const FormatException('Invalid or duplicate chapter history.');
      }
      history.add(ReadingEntry(
          reference, _date(row['visitedAt']), row['completed'] as bool));
    }
    history.sort((a, b) => b.visitedAt.compareTo(a.visitedAt));
    final growth = <GrowthEntry>[];
    final growthIds = <String>{};
    for (final item in _list(raw['growth'] ?? [], 10000)) {
      final entry = GrowthEntry.fromJson(_map(item, 'journal entry'));
      if (!growthIds.add(entry.id)) {
        throw const FormatException('Duplicate journal entry.');
      }
      _translation(entry.translation);
      if (entry.reference != null) {
        _reference(entry.reference, canon);
      } else if (entry.kind == 'session') {
        throw const FormatException(
            'A guided session needs a Scripture reference.');
      }
      growth.add(entry);
    }
    return UserData(
        growth: List.unmodifiable(growth),
        preferences: Map.unmodifiable(preferences),
        bookmarks: Set.unmodifiable(bookmarks),
        notes: Map.unmodifiable(notes),
        highlights: Map.unmodifiable(highlights),
        history: List.unmodifiable(history),
        noteTranslations: Map.unmodifiable(sources));
  }

  static Map<String, dynamic> _map(Object? value, String field) {
    if (value is! Map<String, dynamic>) {
      throw FormatException('Invalid $field.');
    }
    return value;
  }

  static List<dynamic> _list(Object? value, int maximum) {
    if (value is! List || value.length > maximum) {
      throw const FormatException('Invalid or oversized backup records.');
    }
    return value;
  }

  static DateTime _date(Object? value) {
    final parsed =
        value is String && value.length <= 40 ? DateTime.tryParse(value) : null;
    if (parsed == null || parsed.year < 1970 || parsed.year > 9999) {
      throw const FormatException('Invalid backup date.');
    }
    return parsed.toUtc();
  }

  static String _translation(Object? value) {
    if (value is! String || !RegExp(r'^[a-z0-9_-]{1,64}$').hasMatch(value)) {
      throw const FormatException('Invalid translation identifier.');
    }
    return value;
  }

  static String _reference(Object? value, Bible canon,
      {bool chapterOnly = false}) {
    if (value is! String || value.length > 32) {
      throw const FormatException('Invalid Scripture reference.');
    }
    final match = RegExp(chapterOnly
            ? r'^(\w+)\.(\d+)$'
            : r'^(\w+)\.(\d+)\.(\d+)(?:-(\d+))?$')
        .firstMatch(value);
    if (match == null) {
      throw const FormatException('Invalid Scripture reference.');
    }
    final book = canon.books.where((book) => book.id == match[1]);
    final chapter = int.tryParse(match[2]!);
    if (book.isEmpty ||
        chapter == null ||
        chapter < 1 ||
        chapter > book.first.chapters.length) {
      throw const FormatException(
          'A backup reference is outside the supported Bible.');
    }
    if (!chapterOnly) {
      final from = int.tryParse(match[3]!);
      final to = int.tryParse(match[4] ?? match[3]!);
      final maximum = int.parse(
          book.first.chapters[chapter - 1].last.number.split('-').last);
      if (from == null || to == null || from < 1 || to < from || to > maximum) {
        throw const FormatException(
            'A backup verse range is outside its chapter.');
      }
      return ScriptureRange(book.first.id, chapter, from, to).reference;
    }
    return '${book.first.id}.$chapter';
  }
}

class RestoreResult {
  final UserData data;
  final bool translationFallback;
  const RestoreResult(this.data, this.translationFallback);
}

class BackupService {
  final UserDatabase database;
  final Bible canon;
  const BackupService(this.database, this.canon);
  Future<UserBackup> capture() async =>
      UserBackup.create(await database.load(), canon);

  Future<RestoreResult> restore(UserBackup backup, RestoreMode mode) =>
      database.transaction(() async {
        final incoming = backup.data;
        final local = await database.load();
        final merging = mode == RestoreMode.merge;
        final preferences = {
          ...incoming.preferences,
          if (merging) ...local.preferences
        };
        final notes = {...incoming.notes, if (merging) ...local.notes};
        final sources = {
          ...incoming.noteTranslations,
          if (merging) ...local.noteTranslations
        };
        final bookmarks = {
          ...incoming.bookmarks,
          if (merging) ...local.bookmarks
        };
        final highlights = merging
            ? _mergeHighlights(local.highlights, incoming.highlights)
            : incoming.highlights;
        final chapters = {
          for (final entry in incoming.history) entry.reference: entry
        };
        if (merging) {
          for (final entry in local.history) {
            final other = chapters[entry.reference];
            chapters[entry.reference] = other == null
                ? entry
                : ReadingEntry(
                    entry.reference,
                    entry.visitedAt.isAfter(other.visitedAt)
                        ? entry.visitedAt
                        : other.visitedAt,
                    entry.completed || other.completed);
          }
        }
        final translation = preferences['readerTranslation'] ??
            preferences['translation'] ??
            'cebocb';
        bool fallback = false;
        if (translation != 'cebocb') {
          try {
            fallback = await loadInstalledBible(database, translation) == null;
          } catch (_) {
            fallback = true;
          }
        }
        if (fallback) {
          preferences['translation'] = 'cebocb';
          preferences['readerTranslation'] = 'cebocb';
          preferences['scrollOffset'] = '0';
        }
        final growth = {for (final entry in incoming.growth) entry.id: entry};
        if (merging) {
          for (final entry in local.growth) {
            growth[entry.id] = entry;
          }
        }
        final references = {...bookmarks, ...notes.keys, ...highlights.keys};
        await database.batch((batch) {
          batch.customStatement('DELETE FROM preferences');
          batch.customStatement('DELETE FROM annotations');
          batch.customStatement('DELETE FROM reading');
          for (final entry in preferences.entries) {
            batch.customStatement(
                'INSERT INTO preferences (key, value) VALUES (?, ?)',
                [entry.key, entry.value]);
          }
          for (final reference in references) {
            batch.customStatement(
                'INSERT INTO annotations (reference, bookmarked, note, highlight, source_translation) VALUES (?, ?, ?, ?, ?)',
                [
                  reference,
                  bookmarks.contains(reference) ? 1 : 0,
                  notes[reference],
                  highlights[reference],
                  sources[reference] ?? 'cebocb'
                ]);
          }
          for (final entry in chapters.values) {
            batch.customStatement(
                'INSERT INTO reading (reference, visited_at, completed) VALUES (?, ?, ?)',
                [
                  entry.reference,
                  entry.visitedAt.millisecondsSinceEpoch,
                  entry.completed ? 1 : 0
                ]);
          }
        });
        await database.customStatement('DELETE FROM growth_entries');
        if (!merging) await database.customStatement('DELETE FROM growth_seen');
        for (final entry in growth.values) {
          await database.saveGrowth(entry);
        }
        return RestoreResult(await database.load(), fallback);
      });

  static Map<String, int> _mergeHighlights(
      Map<String, int> local, Map<String, int> incoming) {
    final occupied = <String, List<ScriptureRange>>{};
    for (final key in local.keys) {
      final range = ScriptureRange.parse(key);
      (occupied['${range.book}.${range.chapter}'] ??= []).add(range);
    }
    final result = <String, int>{};
    for (final entry in incoming.entries) {
      final range = ScriptureRange.parse(entry.key);
      var pieces = [range];
      for (final existing
          in occupied['${range.book}.${range.chapter}'] ?? <ScriptureRange>[]) {
        pieces = pieces.expand((piece) => piece.without(existing)).toList();
      }
      for (final piece in pieces) {
        result[piece.reference] = entry.value;
      }
    }
    return result..addAll(local);
  }
}
