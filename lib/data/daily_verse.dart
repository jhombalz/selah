import 'dart:convert';
import 'package:http/http.dart' as http;
import 'bible.dart';
import 'user_database.dart';

String dailyVerseDay(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// Well-known passages selected for reflection, with the full chapter available.
const dailyMemoryVerses = [
  'GEN.1.1',
  'JHN.3.16',
  'PSA.23.1',
  'PRO.3.5-6',
  'PHP.4.6-7',
  'MAT.11.28-30',
  'ROM.8.38-39',
  'ISA.40.31',
  'MIC.6.8',
  'JOS.1.9',
  'PSA.46.1',
  'JHN.14.6',
  'GAL.5.22-23',
  'EPH.2.8-10',
  'HEB.11.1',
  '1CO.13.4-7',
  'ROM.12.2',
  'PSA.119.105',
  'MAT.6.33',
  'JAS.1.5',
  '1PE.5.7',
  'JHN.14.27',
  'PSA.27.1',
  '1JN.1.9',
  'HEB.4.16',
  'COL.3.12-14',
  'MAT.5.14-16',
  'ISA.41.10',
  'PHP.4.13',
  'PSA.34.8',
  'JHN.15.5',
  'ROM.5.8',
  '2CO.5.17',
  'PSA.100.4-5',
  'LAM.3.22-23',
  'JAS.1.19',
  'EPH.4.32',
  '1TH.5.16-18',
  '2TI.3.16-17',
  'HEB.12.1-2',
  'PSA.121.1-2',
  'MAT.22.37-39',
  'JHN.13.34-35',
  'ROM.8.1',
  'PRO.16.9',
  'PSA.51.10',
  'COL.3.23-24',
  'GAL.6.9',
  '1CO.10.13',
  'HEB.13.5-6',
  'PSA.19.14',
  'MAT.7.7-8',
  'JHN.16.33',
  'ROM.15.13',
  'EPH.6.10-11',
  'PHP.1.6',
  '2TI.1.7',
  'JAS.4.8',
  '1JN.4.19',
  'REV.21.4',
  'PSA.37.4-5',
  'PRO.4.23',
  'MAT.5.9',
  'LUK.6.31',
  'JHN.8.12',
  'ROM.12.12',
  '1CO.16.13-14',
  '2CO.12.9',
  'GAL.2.20',
  'EPH.3.20-21',
  'PHP.4.8',
  'COL.3.15',
  '1TH.5.11',
  'HEB.10.24-25',
  'JAS.1.22',
  '1PE.4.8',
  '1JN.4.7-8',
  'PSA.56.3',
  'ISA.26.3',
  'DEU.6.5',
];

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

String dailyVerseReference(Bible bible, DateTime date) {
  final available = dailyMemoryVerses
      .where((ref) => availableDailyReference(bible, ref))
      .toList();
  if (available.isEmpty) {
    throw StateError(
        'No daily reflection passages are available in this Bible.');
  }
  final day = DateTime.utc(date.year, date.month, date.day)
      .difference(DateTime.utc(2026, 1, 1))
      .inDays;
  return available[day % available.length];
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
  bool _disposed = false;
  final clients = <http.Client>{};
  final pending = <String, Future<DailyVerseChoice>>{};
  final choices = <String, DailyVerseChoice>{};
  final attempted = <String, DateTime>{};
  static const feed =
      'https://raw.githubusercontent.com/jhombalz/selah/main/web/daily-verses.json';
  Future<DailyVerseChoice> load(Bible bible, DateTime date) {
    final key = '${dailyVerseDay(date)}:${bible.id}';
    return pending.putIfAbsent(
        key,
        () => _load(bible, date, key).whenComplete(() {
              pending.remove(key);
            }));
  }

  Future<DailyVerseChoice> _load(Bible bible, DateTime date, String key) async {
    final day = dailyVerseDay(date);
    var choice =
        choices[key] ?? DailyVerseChoice(dailyVerseReference(bible, date));
    try {
      final cached = await database?.dailyVerse(day);
      if (cached != null &&
          cached.online &&
          dailyMemoryVerses.contains(cached.reference) &&
          availableDailyReference(bible, cached.reference)) {
        choice = DailyVerseChoice(cached.reference, online: true);
      }
    } catch (_) {/* Offline rotation remains available. */}
    if (!choice.online &&
        !_disposed &&
        (attempted[key] == null ||
            DateTime.now().difference(attempted[key]!) >=
                const Duration(minutes: 15))) {
      attempted[key] = DateTime.now();
      final client = clientFactory();
      clients.add(client);
      try {
        final request = await client
            .send(http.Request('GET', Uri.parse(feed)))
            .timeout(const Duration(seconds: 3));
        if (request.statusCode != 200) {
          throw const FormatException('Daily feed unavailable');
        }
        final bytes = <int>[];
        await for (final chunk
            in request.stream.timeout(const Duration(seconds: 3))) {
          bytes.addAll(chunk);
          if (bytes.length > 65536) {
            throw const FormatException('Daily feed too large');
          }
        }
        final data = jsonDecode(utf8.decode(bytes));
        if (data is! Map || data['version'] != 1 || data['references'] is! List) {
          throw const FormatException('Invalid daily feed');
        }
        final refs = (data['references'] as List).whereType<String>().toList();
        if (refs.isEmpty ||
            refs.length > 365 ||
            refs.toSet().length != refs.length ||
            refs.any((ref) =>
                !dailyMemoryVerses.contains(ref) ||
                !availableDailyReference(bible, ref))) {
          throw const FormatException('Invalid daily references');
        }
        final index = DateTime.utc(date.year, date.month, date.day)
            .difference(DateTime.utc(2026, 1, 1))
            .inDays;
        final featured = data['days'] is Map ? data['days'][day] : null;
        final reference = featured is String && refs.contains(featured)
            ? featured
            : refs[index % refs.length];
        choice = DailyVerseChoice(reference, online: true);
      } catch (_) {
        /* Network failure retains the curated local passage. */
      } finally {
        clients.remove(client);
        client.close();
      }
    }
    if (!_disposed) {
      choices[key] = choice;
      try {
        await database?.cacheDailyVerse(day, choice.reference, choice.online);
      } catch (_) {
        /* Daily Scripture still works if the cache cannot be written. */
      }
    }
    return choice;
  }

  void dispose() {
    _disposed = true;
    for (final client in clients.toList()) {
      client.close();
    }
    clients.clear();
  }
}
