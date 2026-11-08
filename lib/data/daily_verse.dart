import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'bible.dart';
import 'user_database.dart';

String dailyVerseDay(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// A stable daily draw from every available verse, including combined verses.
String dailyVerseReference(Bible bible, DateTime date) {
  final total = bible.books.fold<int>(
      0,
      (count, book) =>
          count +
          book.chapters.fold<int>(0, (n, chapter) => n + chapter.length));
  final hash = sha256
      .convert(utf8.encode('selah-daily-${dailyVerseDay(date)}'))
      .toString();
  var index = int.parse(hash.substring(0, 8), radix: 16) % total;
  for (final book in bible.books) {
    for (var chapter = 0; chapter < book.chapters.length; chapter++) {
      final verses = book.chapters[chapter];
      if (index < verses.length) {
        return '${book.id}.${chapter + 1}.${verses[index].number}';
      }
      index -= verses.length;
    }
  }
  throw StateError('This Bible has no verses.');
}

bool availableDailyReference(Bible bible, String reference) {
  final parts = reference.split('.');
  if (parts.length != 3 ||
      !RegExp(r'^[1-9]\d*(?:-[1-9]\d*)?$').hasMatch(parts[2])) {
    return false;
  }
  final books = bible.books.where((book) => book.id == parts[0]);
  final chapter = int.tryParse(parts[1]);
  if (books.isEmpty ||
      chapter == null ||
      chapter < 1 ||
      chapter > books.first.chapters.length) {
    return false;
  }
  return books.first.chapters[chapter - 1].any((verse) =>
      Bible.overlaps(reference, '${parts[0]}.$chapter.${verse.number}'));
}

class DailyVerseChoice {
  final String reference;
  final bool online;
  const DailyVerseChoice(this.reference, {this.online = false});
}

class DailyVerseRepository {
  final UserDatabase? database;
  final http.Client Function() clientFactory;
  DailyVerseRepository({this.database, http.Client Function()? clientFactory})
      : clientFactory = clientFactory ?? http.Client.new;
  final _clients = <http.Client>{};
  final _memory = <String, DailyVerseChoice>{};
  final _attempted = <String, DateTime>{};
  bool _disposed = false;

  Future<DailyVerseChoice> load(Bible bible, DateTime date) async {
    final day = dailyVerseDay(date);
    var cachedChoice = _memory[day];
    if (cachedChoice == null && database != null && !_disposed) {
      try {
        final cached = await database!.dailyVerse(day);
        if (cached != null &&
            availableDailyReference(bible, cached.reference)) {
          cachedChoice =
              DailyVerseChoice(cached.reference, online: cached.online);
        }
      } catch (_) {
        /* The reader remains usable if cache storage is unavailable. */
      }
    }
    var choice =
        cachedChoice ?? DailyVerseChoice(dailyVerseReference(bible, date));
    if (!availableDailyReference(bible, choice.reference)) {
      choice = DailyVerseChoice(dailyVerseReference(bible, date));
    }
    if (!choice.online &&
        !_disposed &&
        (_attempted[day] == null ||
            DateTime.now().difference(_attempted[day]!) >=
                const Duration(seconds: 15))) {
      _attempted
        ..clear()
        ..[day] = DateTime.now();
      final client = clientFactory();
      _clients.add(client);
      try {
        // Only use the reference. Scripture always comes from the selected Bible.
        final response = await client
            .get(Uri.parse('https://bible-api.com/data/web/random'))
            .timeout(const Duration(seconds: 8));
        if (response.statusCode == 200 && response.bodyBytes.length <= 65536) {
          final data = jsonDecode(response.body);
          final verse = data is Map ? data['random_verse'] : null;
          if (verse is Map &&
              verse['book_id'] is String &&
              verse['chapter'] is int &&
              verse['verse'] is int) {
            final reference =
                '${verse['book_id']}.${verse['chapter']}.${verse['verse']}';
            if (availableDailyReference(bible, reference)) {
              choice = DailyVerseChoice(reference, online: true);
            }
          }
        }
      } catch (_) {
        /* Offline, timeout, and invalid responses use local Scripture. */
      } finally {
        _clients.remove(client);
        client.close();
      }
    }
    if (!_disposed) {
      _memory
        ..clear()
        ..[day] = choice;
      try {
        await database?.cacheDailyVerse(day, choice.reference, choice.online);
      } catch (_) {/* Best-effort cache. */}
    }
    return choice;
  }

  void dispose() {
    _disposed = true;
    for (final client in _clients.toList()) {
      client.close();
    }
    _clients.clear();
  }
}
