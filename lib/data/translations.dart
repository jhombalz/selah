import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'bible.dart';
import 'book_names.dart';
import 'user_database.dart';

class TranslationSpec {
  final String id, title, abbreviation, language, sourceId, textHash, license;
  const TranslationSpec(this.id, this.title, this.abbreviation, this.language,
      this.sourceId, this.textHash, this.license);
  String get source => 'https://ebible.org/Scriptures/${sourceId}_vpl.zip';
}

const translationCatalog = [
  TranslationSpec(
      'cebocb',
      'Biblica® Open Ang Pulong sa Dios™',
      'OCCB',
      'Cebuano',
      'cebocb',
      '',
      'CC BY-SA 4.0 · © 2009, 2010, 2014, 2024 Biblica, Inc.\nhttps://ebible.org/cebocb/copyright.htm'),
  TranslationSpec(
      'web',
      'World English Bible',
      'WEB',
      'English',
      'engwebp',
      '5a150b653d07369448a792ec2baaf9133ba6c582d7a0609cdcd72e185a06c45b',
      'World English Bible — Public Domain.\n“World English Bible” is a trademark of eBible.org. Scripture wording has not been changed. This edition includes the 66-book protocanon.\nhttps://ebible.org/engwebp/copyright.htm'),
  TranslationSpec(
      'bsb',
      'Berean Standard Bible',
      'BSB',
      'English',
      'engbsb',
      '5a7306db92b3152ca3bb8c1fd6d28177172845c08c67db205337ae731aaabaab',
      'Berean Standard Bible — Public Domain.\nContributor: BSB Publishing, LLC.\nhttps://ebible.org/engbsb/copyright.htm'),
  TranslationSpec(
      'tglulb',
      'Banal na Bibliya (Tagalog Unlocked Literal Bible)',
      'ULB',
      'Tagalog',
      'tglulb',
      '8410580c8ce8804e5eaf6246b1cc5c1e63956d48590c34659e1c369575ecdf6c',
      'Tagalog Unlocked Literal Bible · © 2018 Door43 World Missions Community.\nCC BY-SA 4.0 · https://creativecommons.org/licenses/by-sa/4.0/\nFull contributor credits and source: https://ebible.org/tglulb/copyright.htm\nThe text is unchanged; source formatting, footnotes and headings are omitted.'),
  TranslationSpec(
      'asv',
      'American Standard Version (1901)',
      'ASV',
      'English',
      'eng-asv',
      '8924ef74086d572425b1e335f531c7c529a561969e5c851e456b84c2ce6ad858',
      'American Standard Version (1901) — Public Domain.\nProvided by eBible.org. Scripture wording has not been changed.\nhttps://ebible.org/eng-asv/copyright.htm'),
  TranslationSpec(
      'cebulb',
      'Balaan nga Bibliya (Cebuano Unlocked Literal Bible)',
      'ULB',
      'Cebuano',
      'cebulb',
      'd60ffb97d0d5816d00396c62812ec469bf7d9880de41ed392c6d8a9254661509',
      'Cebuano Unlocked Literal Bible · © 2019 Door43 World Missions Community.\nCC BY-SA 4.0 · https://creativecommons.org/licenses/by-sa/4.0/\nContributors: Aida Espelita, Aira Amaran, Alma Mae Llorca, Amelina Emboc, Analine Tanog, Bernaly Mansiwagan, Carwelene Amper, Chally Lou Lacaran, Charity Guinita, Dan Bongcalas, Darryl Lasquite, Divine Grace Leparto, Elsie Lacubay, Ernilyn Balindong, Gem Lalaan, Helen Thundas, Jerome Resomadero, Jeryl Tumundog, Johnny Ray Lumawan, Loreto Socias Jr., Luthero Pulao Jr., Lymae Belle Ednalgan, Marilyn Lay-um, Mark Kevin Atab, Marth Anthony Atab, Miracle Marcojos, Molly, Noel Dalumatao, Rico Barrios, Ricky Mansabid, Romeo Lumasay, Roselle Lay-um, Steven Lubosan, Jeffrey, Johanna, Junette, Benny, and Racquel.\nhttps://ebible.org/cebulb/copyright.htm\nScripture wording is unchanged; source formatting, footnotes and headings are omitted. Redistribution of this translation remains under CC BY-SA 4.0.'),
  TranslationSpec(
      'kjv',
      'King James Version',
      'KJV',
      'English',
      'eng-kjv2006',
      '68c5f764bf1c204868c3eb72592035c0947f057b608c2149dbff765d8ddd86f6',
      'King James (Authorized) Version — Public Domain outside the United Kingdom.\nRights in the United Kingdom are vested in the Crown; this edition is intended for use where public-domain status applies, including the Philippines.\nSource: eBible.org, eng-kjv2006. Scripture wording has not been changed.\nhttps://ebible.org/eng-kjv2006/'),
];

class DownloadCancelled implements Exception {}

class TranslationDownloader {
  final http.Client Function() clientFactory;
  TranslationDownloader({http.Client Function()? clientFactory})
      : clientFactory = clientFactory ?? http.Client.new;
  http.Client? _client;
  bool _cancelled = false;
  void cancel() {
    _cancelled = true;
    _client?.close();
  }

  Future<Bible> download(TranslationSpec spec, Bible bundled,
      void Function(double?, String) progress) async {
    if (spec.id == 'cebocb') {
      throw ArgumentError('The Cebuano Bible is already bundled.');
    }
    _cancelled = false;
    final client = _client = clientFactory();
    try {
      final uri = kIsWeb
          ? Uri.base.resolve('translations/${spec.id}.zip')
          : Uri.parse(spec.source);
      final response = await client
          .send(http.Request('GET', uri))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw StateError(
            'Download unavailable (HTTP ${response.statusCode}). Please try again.');
      }
      final bytes = BytesBuilder(copy: false);
      final length = response.contentLength;
      await for (final chunk
          in response.stream.timeout(const Duration(seconds: 30))) {
        if (_cancelled) throw DownloadCancelled();
        bytes.add(chunk);
        if (bytes.length > 12 * 1024 * 1024) {
          throw const FormatException('Translation package is too large.');
        }
        progress(
            length == null || length == 0
                ? null
                : (bytes.length / length).clamp(0, 1) * .85,
            'Downloading ${spec.abbreviation}');
      }
      progress(.88, 'Checking package integrity');
      await Future<void>.delayed(Duration.zero);
      final archive = ZipDecoder().decodeBytes(bytes.takeBytes(), verify: true);
      final entries = archive.files
          .where((file) => file.name == '${spec.sourceId}_vpl.txt')
          .toList();
      if (entries.length != 1 || entries.single.size > 12 * 1024 * 1024) {
        throw const FormatException(
            'The package does not contain the expected Bible text.');
      }
      final textBytes = entries.single.content;
      if (sha256.convert(textBytes).toString() != spec.textHash) {
        throw const FormatException(
            'This package differs from the verified edition. Please update the app before downloading it.');
      }
      progress(.92, 'Validating all 66 books');
      final bible = await parseTranslation(
          utf8.decode(textBytes), spec, bundled,
          cancelled: () => _cancelled);
      if (_cancelled) throw DownloadCancelled();
      return bible;
    } catch (_) {
      if (_cancelled) throw DownloadCancelled();
      rethrow;
    } finally {
      client.close();
      _client = null;
    }
  }
}

Future<Bible> parseTranslation(String text, TranslationSpec spec, Bible bundled,
    {bool Function()? cancelled}) async {
  final chapters = {
    for (final book in bundled.books)
      book.id: List.generate(book.chapters.length, (_) => <BibleVerse>[])
  };
  final seen = <String>{};
  int count = 0;
  for (final line
      in const LineSplitter().convert(text.replaceFirst('\ufeff', ''))) {
    if (line.trim().isEmpty) continue;
    final match = RegExp(r'^(\w+) (\d+):(\d+(?:-\d+)?) (.*)$').firstMatch(line);
    if (match == null) throw const FormatException('Invalid verse data.');
    final id = _aliases[match[1]] ?? match[1]!;
    final chapter = int.parse(match[2]!) - 1;
    final verses = chapters[id];
    final label = match[3]!;
    final number = label.split('-').map(int.parse).toList();
    if (verses == null ||
        chapter < 0 ||
        chapter >= verses.length ||
        number.first < 1 ||
        number.last < number.first ||
        number.last > 200 ||
        !seen.add('$id.$chapter.$label')) {
      throw const FormatException('Invalid or duplicate Scripture reference.');
    }
    final target = verses[chapter];
    if (target.isNotEmpty &&
        int.parse(target.last.number.split('-').last) >= number.first) {
      throw const FormatException('Verse references are out of order.');
    }
    // VPL exports retain empty placeholders for verses absent in this edition.
    if (match[4]!.trim().isEmpty) continue;
    target.add(BibleVerse(label, match[4]!));
    count++;
    if (count % 512 == 0) {
      await Future<void>.delayed(Duration.zero);
      if (cancelled?.call() ?? false) throw DownloadCancelled();
    }
  }
  final baseline = bundled.books.fold<int>(
      0, (sum, b) => sum + b.chapters.fold<int>(0, (n, c) => n + c.length));
  if (count < baseline * .9 ||
      chapters.values.any((book) => book.any((chapter) => chapter.isEmpty))) {
    throw const FormatException('The downloaded Bible is incomplete.');
  }
  return Bible.withReadingFormat(Bible([
    for (int i = 0; i < bundled.books.length; i++)
      BibleBook(
          bundled.books[i].id,
          spec.language == 'Cebuano'
              ? cebuanoBookNames[i]
              : englishBookNames[i],
          chapters[bundled.books[i].id]!)
  ], spec.title,
      id: spec.id,
      abbreviation: spec.abbreviation,
      language: spec.language,
      licenseText:
          '${spec.license}\n\nSource: ${spec.source}\nScripture wording is unchanged. Available edition-matched reading metadata is supplied separately from AO Lab.${spec.id == 'tglulb' ? '\n\n${await rootBundle.loadString('assets/bible/tglulb-LICENSE.txt')}' : ''}'));
}

Future<Bible?> loadInstalledBible(UserDatabase database, String id) async {
  final stored = await database.translation(id);
  if (stored == null) return null;
  if (sha256.convert(utf8.encode(stored.content)).toString() !=
      stored.checksum) {
    throw const FormatException(
        'The saved translation failed its integrity check. Remove it and download again.');
  }
  final bible = await Bible.decode(stored.content);
  if (bible.id != id) {
    throw const FormatException('Translation identifier mismatch.');
  }
  return Bible.withReadingFormat(bible);
}

const _aliases = {
  'SOL': 'SNG',
  'EZE': 'EZK',
  'JOE': 'JOL',
  'NAH': 'NAM',
  'MAR': 'MRK',
  'JOH': 'JHN',
  'PHI': 'PHP',
  'JAM': 'JAS',
  '1JO': '1JN',
  '2JO': '2JN',
  '3JO': '3JN'
};
