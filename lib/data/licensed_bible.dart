import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'bible.dart';
import 'reading_format.dart';
import 'user_database.dart';

class LicensedEdition {
  final String id, apiId, name, abbreviation;
  const LicensedEdition(this.id, this.apiId, this.name, this.abbreviation);
}

const licensedEditions = [
  LicensedEdition(
      'niv', '78a9f6124f344018-01', 'New International Version 2011', 'NIV'),
  LicensedEdition(
      'nlt', 'd6e14a625393b4da-01', 'New Living Translation', 'NLT'),
];

class LicensedBibleAccess {
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static const key = String.fromEnvironment('API_BIBLE_KEY');
  static bool get available => supported && key.isNotEmpty;
}

class LicensedChapter {
  final LicensedEdition edition;
  final String book, copyright;
  final int chapter;
  final List<BibleVerse> verses;
  final DateTime fetchedAt;
  final bool cached, refreshFailed, cacheFailed;
  const LicensedChapter(
      {required this.edition,
      required this.book,
      required this.chapter,
      required this.copyright,
      required this.verses,
      required this.fetchedAt,
      this.cached = false,
      this.refreshFailed = false,
      this.cacheFailed = false});
  String get reference => '$book.$chapter';
  bool fresh(DateTime now) =>
      !now.isBefore(fetchedAt) &&
      now.difference(fetchedAt) < const Duration(days: 30);
  LicensedChapter copy(
          {bool? cached, bool? refreshFailed, bool? cacheFailed}) =>
      LicensedChapter(
          edition: edition,
          book: book,
          chapter: chapter,
          copyright: copyright,
          verses: verses,
          fetchedAt: fetchedAt,
          cached: cached ?? this.cached,
          refreshFailed: refreshFailed ?? this.refreshFailed,
          cacheFailed: cacheFailed ?? this.cacheFailed);
}

/// On-demand chapter access only. No key is stored in SQLite or user backups.
class LicensedBibleRepository {
  final UserDatabase database;
  final String apiKey;
  final DateTime Function() now;
  final http.Client client;
  bool _disposed = false;
  final _pending = <String, Future<LicensedChapter>>{};
  LicensedBibleRepository(this.database,
      {String? apiKey, DateTime Function()? now, http.Client? client})
      : apiKey = apiKey ?? LicensedBibleAccess.key,
        now = now ?? DateTime.now,
        client = client ?? http.Client();

  Future<LicensedChapter> load(
      LicensedEdition edition, String book, int chapter,
      {bool refresh = false}) {
    if (_disposed) throw StateError('Reader closed.');
    if (!licensedEditions
            .any((e) => e.id == edition.id && e.apiId == edition.apiId) ||
        !RegExp(r'^[A-Z0-9]{3}$').hasMatch(book) ||
        chapter < 1 ||
        chapter > 150) {
      throw ArgumentError('Invalid Scripture reference.');
    }
    final key = '${edition.id}:$book.$chapter';
    return _pending.putIfAbsent(
        key,
        () => _load(edition, book, chapter, key, refresh).whenComplete(() {
              _pending.remove(key);
            }));
  }

  Future<LicensedChapter> _load(LicensedEdition edition, String book,
      int chapter, String key, bool refresh) async {
    LicensedChapter? cached;
    final rows = await database.customSelect(
        'SELECT content, fetched_at FROM licensed_chapter_cache WHERE reference=?',
        variables: [Variable(key)]).get();
    if (rows.isNotEmpty) {
      try {
        final row = rows.single;
        cached = parse(
                jsonDecode(row.read<String>('content')) as Map<String, dynamic>,
                edition,
                book,
                chapter,
                DateTime.fromMillisecondsSinceEpoch(row.read<int>('fetched_at'),
                    isUtc: true))
            .copy(cached: true);
      } catch (_) {
        cached = null;
      }
      if (cached == null || !cached.fresh(now())) {
        await database.customStatement(
            'DELETE FROM licensed_chapter_cache WHERE reference=?', [key]);
        cached = null;
      } else if (!refresh) {
        await database.customStatement(
            'UPDATE licensed_chapter_cache SET accessed_at=? WHERE reference=?',
            [now().millisecondsSinceEpoch, key]);
        return cached;
      }
    }
    try {
      if (apiKey.isEmpty) {
        throw StateError('Online editions are not configured in this build.');
      }
      final uri = Uri.https('rest.api.bible',
          '/v1/bibles/${edition.apiId}/chapters/$book.$chapter', {
        'content-type': 'json',
        'include-notes': 'false',
        'include-titles': 'true',
        'include-verse-numbers': 'false'
      });
      final request = await client
          .send(http.Request('GET', uri)
            ..followRedirects = false
            ..headers['api-key'] = apiKey)
          .timeout(const Duration(seconds: 20));
      if (request.statusCode != 200) {
        await request.stream.drain<void>();
        throw StateError(switch (request.statusCode) {
          401 ||
          403 =>
            'This edition is unavailable for the current API access.',
          429 =>
            'The online reading limit has been reached. Try a saved chapter or an offline edition.',
          _ => 'The chapter is unavailable. Please try again.'
        });
      }
      final bytes = <int>[];
      await for (final chunk
          in request.stream.timeout(const Duration(seconds: 20))) {
        bytes.addAll(chunk);
        if (bytes.length > 1500000) {
          throw const FormatException('Chapter response too large.');
        }
      }
      if (_disposed) throw StateError('Reader closed.');
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>;
      final fetched = now().toUtc();
      final result = parse(data, edition, book, chapter, fetched);
      try {
        await database.transaction(() async {
          await database.customStatement(
              '''INSERT INTO licensed_chapter_cache
            (reference, content, fetched_at, accessed_at) VALUES (?,?,?,?)
            ON CONFLICT(reference) DO UPDATE SET content=excluded.content,
            fetched_at=excluded.fetched_at, accessed_at=excluded.accessed_at''',
              [
                key,
                jsonEncode(data),
                fetched.millisecondsSinceEpoch,
                fetched.millisecondsSinceEpoch
              ]);
          await database.customStatement(
              '''DELETE FROM licensed_chapter_cache WHERE reference NOT IN
            (SELECT reference FROM licensed_chapter_cache ORDER BY accessed_at DESC, reference DESC LIMIT 60)''');
        });
      } catch (_) {
        return result.copy(cacheFailed: true);
      }
      return result;
    } catch (error) {
      if (cached != null && cached.fresh(now())) {
        return cached.copy(refreshFailed: true);
      }
      if (error is StateError || error is FormatException) rethrow;
      throw StateError(
          'Internet is needed to open this chapter. Saved chapters remain available for up to 30 days.');
    }
  }

  static LicensedChapter parse(Map<String, dynamic> data,
      LicensedEdition edition, String book, int chapter, DateTime fetched) {
    final copyright = data['copyright'];
    if (data['id'] != '$book.$chapter' ||
        data['bibleId'] != edition.apiId ||
        data['bookId'] != book ||
        '${data['number']}' != '$chapter' ||
        copyright is! String ||
        copyright.trim().isEmpty ||
        copyright.length > 20000 ||
        data['content'] is! List) {
      throw const FormatException('Unexpected edition or chapter data.');
    }
    final texts = <String, StringBuffer>{}, headings = <String, List<String>>{};
    final pendingHeadings = <String>[];
    String? reference;
    int count = 0;
    String? resolve(Object? raw) {
      if (raw is! String) return null;
      final match = RegExp('^${RegExp.escape('$book.$chapter')}'
              r'\.(\d+)(?:-(?:[A-Z0-9]{3}\.\d+\.)?(\d+))?$')
          .firstMatch(raw);
      if (match == null) {
        throw const FormatException('Invalid verse reference.');
      }
      final first = int.parse(match[1]!),
          last = int.parse(match[2] ?? match[1]!);
      if (first < 1 || last < first || last > 200) {
        throw const FormatException('Invalid verse range.');
      }
      return first == last ? '$first' : '$first-$last';
    }

    String plain(dynamic node) {
      if (node is! Map) return '';
      if (node['type'] == 'text') return node['text'] as String? ?? '';
      return (node['items'] as List? ?? []).map(plain).join();
    }

    void walk(dynamic node, int depth) {
      if (depth > 20 || ++count > 30000 || node is! Map) {
        throw const FormatException('Invalid chapter structure.');
      }
      final attrs = node['attrs'] as Map? ?? const {};
      final style = attrs['style'] as String? ?? '';
      if (RegExp(r'^(s\d*|ms\d*|mt\d*)$').hasMatch(style)) {
        final text = plain(node).trim();
        if (text.isNotEmpty) pendingHeadings.add(text);
        reference = null;
        return;
      }
      if (node['name'] == 'note' ||
          const {'f', 'x', 'r', 'sr', 'sp'}.contains(style)) {
        return;
      }
      final id = attrs['verseId'];
      if (id != null) reference = resolve(id);
      if (node['name'] == 'verse' && attrs['number'] != null) {
        reference = resolve('$book.$chapter.${attrs['number']}');
      }
      if (node['type'] == 'text') {
        final text = node['text'];
        if (text is! String) {
          throw const FormatException('Invalid Scripture text.');
        }
        if (reference != null && text.isNotEmpty) {
          final key = reference!;
          if (!texts.containsKey(key)) {
            texts[key] = StringBuffer();
            if (pendingHeadings.isNotEmpty) {
              headings[key] = List.of(pendingHeadings);
              pendingHeadings.clear();
            }
          }
          texts[key]!.write(text);
        }
      } else {
        final children = node['items'];
        if (children != null && children is! List) {
          throw const FormatException('Invalid chapter structure.');
        }
        for (final child in children as List? ?? []) {
          walk(child, depth + 1);
        }
      }
    }

    for (final node in data['content'] as List) {
      walk(node, 0);
    }
    final verses = <BibleVerse>[];
    var previous = 0;
    for (final entry in texts.entries) {
      final bounds = entry.key.split('-').map(int.parse).toList();
      if (bounds.first <= previous) {
        throw const FormatException('Overlapping verse references.');
      }
      previous = bounds.last;
      final text = entry.value.toString().trim();
      if (text.isEmpty) continue;
      verses.add(BibleVerse(entry.key, text,
          readingFormat: ReadingFormat(
              headings: headings[entry.key] ?? const [],
              segments: [ScriptureSegment(text)])));
    }
    if (verses.isEmpty || verses.length > 200) {
      throw const FormatException('Chapter contains no Scripture.');
    }
    return LicensedChapter(
        edition: edition,
        book: book,
        chapter: chapter,
        copyright: copyright,
        verses: verses,
        fetchedAt: fetched);
  }

  Future<void> clear() =>
      database.customStatement('DELETE FROM licensed_chapter_cache');
  void dispose() {
    _disposed = true;
    client.close();
  }
}
