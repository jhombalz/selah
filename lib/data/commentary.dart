import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'scripture_range.dart';
import 'user_database.dart';

const studyNotesName = 'Tyndale Open Study Notes';
const studyNotesSource = 'https://tyndaleopenresources.com/';
const studyNotesLicense = 'https://creativecommons.org/licenses/by-sa/4.0/';

class StudyNote {
  final int anchor;
  final String text;
  const StudyNote(this.anchor, this.text);
  bool matches(ScriptureRange range) {
    var first = anchor, last = anchor;
    // The API anchors a ranged note at its first verse. Only parse its leading
    // reference, never the cross-references mentioned inside its prose.
    final match =
        RegExp(r'^(\d+):(\d+)(?:\s*[-–—]\s*(?:(\d+):)?(\d+))?(?=\s|$)')
            .firstMatch(text);
    if (match != null &&
        int.parse(match[1]!) == range.chapter &&
        int.parse(match[2]!) == anchor) {
      first = int.parse(match[2]!);
      if (match[4] != null) {
        final endChapter = int.parse(match[3] ?? match[1]!);
        last = endChapter > range.chapter ? 10000 : int.parse(match[4]!);
      }
    }
    return first <= range.end && range.start <= last;
  }
}

class StudyChapter {
  final String book;
  final int chapter;
  final List<StudyNote> notes;
  final DateTime fetchedAt;
  final String licenseNotes, licenseNotice;
  final bool cached, cacheFailed, refreshFailed;
  const StudyChapter(
      {required this.book,
      required this.chapter,
      required this.notes,
      required this.fetchedAt,
      this.licenseNotes = '',
      this.licenseNotice = '',
      this.cached = false,
      this.cacheFailed = false,
      this.refreshFailed = false});
  StudyChapter copy({bool? cached, bool? cacheFailed, bool? refreshFailed}) =>
      StudyChapter(
          book: book,
          chapter: chapter,
          notes: notes,
          fetchedAt: fetchedAt,
          licenseNotes: licenseNotes,
          licenseNotice: licenseNotice,
          cached: cached ?? this.cached,
          cacheFailed: cacheFailed ?? this.cacheFailed,
          refreshFailed: refreshFailed ?? this.refreshFailed);
  Map<String, dynamic> toJson() => {
        'version': 1,
        'source': 'tyndale',
        'book': book,
        'chapter': chapter,
        'fetchedAt': fetchedAt.toIso8601String(),
        'licenseNotes': licenseNotes,
        'licenseNotice': licenseNotice,
        'notes': [
          for (final note in notes) {'number': note.anchor, 'text': note.text}
        ],
      };
  static List<StudyNote> _notes(List<dynamic> rows) {
    if (rows.length > 1000) {
      throw const FormatException('Too many study notes.');
    }
    return [
      for (final row in rows)
        (() {
          if (row is! Map ||
              row['number'] is! int ||
              row['number'] < 1 ||
              row['number'] > 200 ||
              row['text'] is! String ||
              (row['text'] as String).length > 100000) {
            throw const FormatException('Invalid study note.');
          }
          return StudyNote(row['number'] as int, row['text'] as String);
        })()
    ];
  }

  factory StudyChapter.fromCache(
      Map<String, dynamic> value, String book, int chapter) {
    if (value['version'] != 1 ||
        value['source'] != 'tyndale' ||
        value['book'] != book ||
        value['chapter'] != chapter) {
      throw const FormatException('Study notes do not match this passage.');
    }
    return StudyChapter(
        book: book,
        chapter: chapter,
        fetchedAt: DateTime.parse(value['fetchedAt'] as String).toUtc(),
        notes: _notes(value['notes'] as List<dynamic>),
        licenseNotes: value['licenseNotes'] as String? ?? '',
        licenseNotice: value['licenseNotice'] as String? ?? '',
        cached: true);
  }
  factory StudyChapter.fromApi(
      Map<String, dynamic> value, String book, int chapter) {
    final source = value['commentary'];
    final data = value['chapter'];
    if (source is! Map ||
        source['id'] != 'tyndale' ||
        source['language'] != 'eng' ||
        source['licenseUrl'] != studyNotesLicense ||
        value['book'] is! Map ||
        value['book']['id'] != book ||
        data is! Map ||
        data['number'] != chapter ||
        data['content'] is! List) {
      throw const FormatException('Unexpected study-notes response.');
    }
    final rows = data['content'] as List;
    if (rows.any((row) => row is! Map || row['type'] != 'verse')) {
      throw const FormatException('Invalid commentary chapter content.');
    }
    final notes = _notes(rows);
    final licenseNotes = source['licenseNotes'] as String? ?? '';
    final notice = source['licenseNotice'] as String? ?? '';
    if (licenseNotes.length > 16000 || notice.length > 16000) {
      throw const FormatException('Invalid source notice.');
    }
    return StudyChapter(
        book: book,
        chapter: chapter,
        notes: notes,
        fetchedAt: DateTime.now().toUtc(),
        licenseNotes: licenseNotes,
        licenseNotice: notice);
  }
}

class StudyNotesRepository {
  final UserDatabase database;
  final http.Client Function() clientFactory;
  StudyNotesRepository(this.database, {http.Client Function()? clientFactory})
      : clientFactory = clientFactory ?? http.Client.new;
  final _clients = <http.Client>{};
  bool _disposed = false;
  String key(String book, int chapter) => 'tyndale:$book.$chapter';
  Future<void> remove(String book, int chapter) => database.customStatement(
      'DELETE FROM commentary_cache WHERE reference = ?', [key(book, chapter)]);
  Future<StudyChapter> load(String book, int chapter,
      {bool refresh = false}) async {
    if (_disposed) throw StateError('Study notes are closed.');
    if (!RegExp(r'^[A-Z0-9]{3}$').hasMatch(book) ||
        chapter < 1 ||
        chapter > 150) {
      throw ArgumentError('Invalid passage.');
    }
    StudyChapter? saved;
    try {
      final row = await database.customSelect(
          'SELECT content FROM commentary_cache WHERE reference = ?',
          variables: [Variable(key(book, chapter))]).getSingleOrNull();
      if (row != null) {
        saved = StudyChapter.fromCache(
            jsonDecode(row.read<String>('content')) as Map<String, dynamic>,
            book,
            chapter);
        await database.customStatement(
            'UPDATE commentary_cache SET accessed_at = ? WHERE reference = ?',
            [DateTime.now().millisecondsSinceEpoch, key(book, chapter)]);
      }
    } on FormatException {
      await remove(book, chapter);
    } on TypeError {
      await remove(book, chapter);
    }
    if (saved != null && !refresh) return saved;
    if (_disposed) throw StateError('Study notes are closed.');
    final client = clientFactory();
    _clients.add(client);
    try {
      final response = await client
          .get(Uri.https(
              'bible.helloao.org', '/api/c/tyndale/$book/$chapter.simple.json'))
          .timeout(const Duration(seconds: 15));
      if (_disposed) throw StateError('Study notes are closed.');
      StudyChapter result;
      if (response.statusCode == 404) {
        result = StudyChapter(
            book: book,
            chapter: chapter,
            notes: const [],
            fetchedAt: DateTime.now().toUtc());
      } else {
        if (response.statusCode != 200) {
          throw StateError('Study notes could not be downloaded.');
        }
        if (response.bodyBytes.length > 4 * 1024 * 1024) {
          throw const FormatException('Study notes are too large.');
        }
        result = StudyChapter.fromApi(
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
            book,
            chapter);
      }
      try {
        await database.transaction(() async {
          await database.customStatement(
              'INSERT INTO commentary_cache (reference, content, accessed_at) VALUES (?, ?, ?) ON CONFLICT(reference) DO UPDATE SET content=excluded.content, accessed_at=excluded.accessed_at',
              [
                key(book, chapter),
                jsonEncode(result.toJson()),
                DateTime.now().millisecondsSinceEpoch
              ]);
          await database.customStatement(
              'DELETE FROM commentary_cache WHERE reference NOT IN (SELECT reference FROM commentary_cache ORDER BY accessed_at DESC, reference LIMIT 100)');
        });
      } catch (_) {
        result = result.copy(cacheFailed: true);
      }
      return result;
    } catch (_) {
      if (saved != null && !_disposed) return saved.copy(refreshFailed: true);
      rethrow;
    } finally {
      _clients.remove(client);
      client.close();
    }
  }

  void dispose() {
    _disposed = true;
    for (final client in _clients) {
      client.close();
    }
    _clients.clear();
  }
}
