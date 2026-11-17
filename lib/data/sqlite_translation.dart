import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:sqlite3/common.dart';
import 'package:typed_data/typed_buffers.dart';
import 'package:xml/xml.dart';
import 'bible.dart';
import 'xml_translation.dart';
import 'sqlite_import_native.dart'
    if (dart.library.js_interop) 'sqlite_import_web.dart';

// MyBible book numbers include gaps for additional books. Select the same
// 66-book canon as SELAH, using the canonical Esther and Daniel versions.
const myBibleCanonNumbers = [
  10,
  20,
  30,
  40,
  50,
  60,
  70,
  80,
  90,
  100,
  110,
  120,
  130,
  140,
  150,
  160,
  190,
  220,
  230,
  240,
  250,
  260,
  290,
  300,
  310,
  330,
  340,
  350,
  360,
  370,
  380,
  390,
  400,
  410,
  420,
  430,
  440,
  450,
  460,
  470,
  480,
  490,
  500,
  510,
  520,
  530,
  540,
  550,
  560,
  570,
  580,
  590,
  600,
  610,
  620,
  630,
  640,
  650,
  660,
  670,
  680,
  690,
  700,
  710,
  720,
  730
];

String plainMyBibleText(String text) {
  if (text.length > 50000) throw const FormatException('Verse too long');
  // Footnote links are metadata. Poetry, emphasis and table text stay intact.
  final cleaned = text
      .replaceAll(RegExp(r'<f>.*?</f>', dotAll: true), '')
      .replaceAll('<pb/>', '\n')
      .replaceAll('<t>', '\n')
      .replaceAll('</t>', '\n')
      .replaceAll(RegExp(r'</?(?:n|i|e)>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAllMapped(
          RegExp(r'&(?!(?:amp|lt|gt|quot|apos|#\d+|#x[0-9a-fA-F]+);)'),
          (_) => '&amp;');
  final root = XmlDocument.parse('<r>$cleaned</r>').rootElement;
  if (root.childElements.isNotEmpty) {
    throw const FormatException('Unexpected verse markup');
  }
  return root.innerText
      .replaceAll(RegExp(r'[ \t\u00a0]+'), ' ')
      .replaceAll(RegExp(r' *\n *'), '\n')
      .replaceAll(RegExp(r'\n+'), '\n')
      .trim();
}

String _xmlText(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

Future<Bible> parseSqliteTranslation(
    (Uint8List, Bible, String, String) input) async {
  final (compressed, canon, id, license) = input;
  final bytes = GZipDecoder().decodeBytes(compressed);
  if (bytes.length > 24 * 1024 * 1024 ||
      bytes.length < 100 ||
      String.fromCharCodes(bytes.take(15)) != 'SQLite format 3') {
    throw const FormatException('Invalid Bible database');
  }
  final engine = await importSqliteEngine();
  final fs = InMemoryFileSystem(
      name:
          'selah-import-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(0x7fffffff)}');
  fs.fileData['/source.sqlite'] = Uint8Buffer()..addAll(bytes);
  engine.registerVirtualFileSystem(fs);
  CommonDatabase? db;
  try {
    db = engine.open('/source.sqlite', vfs: fs.name, mode: OpenMode.readOnly);
    db.execute('PRAGMA trusted_schema=OFF');
    db.execute('PRAGMA query_only=ON');
    final tables = db.select(
        "SELECT name,type,sql FROM sqlite_master WHERE name IN ('info','books','verses')");
    if (tables.length != 3 ||
        tables.any((r) =>
            r['type'] != 'table' ||
            (r['sql'] as String).toUpperCase().contains('VIRTUAL TABLE'))) {
      throw const FormatException('Unexpected Bible database schema');
    }
    final info = {
      for (final row in db.select('SELECT name,value FROM info'))
        row['name'] as String: row['value'] as String
    };
    if (info['description'] != 'Magandang Balita Biblia, 2005' ||
        info['language'] != 'tl') {
      throw const FormatException('This is not the expected MBB05 edition');
    }
    final sourceBooks = {
      for (final row in db.select('SELECT book_number,long_name FROM books'))
        row['book_number'] as int: row['long_name'] as String
    };
    final xml = StringBuffer('<bible>');
    var count = 0;
    final names = <String>[];
    for (var b = 0; b < 66; b++) {
      final number = myBibleCanonNumbers[b];
      final name = sourceBooks[number];
      if (name == null || name.trim().isEmpty || name.length > 100) {
        throw const FormatException('Missing Bible book');
      }
      names.add(name);
      final rows = db.select(
          'SELECT chapter,verse,text FROM verses WHERE book_number=? ORDER BY chapter,verse',
          [number]);
      final expected = canon.books[b].chapters.length;
      xml.write('<book number="${b + 1}">');
      var offset = 0;
      for (var c = 1; c <= expected; c++) {
        xml.write('<chapter number="$c">');
        var entries = 0;
        while (offset < rows.length && rows[offset]['chapter'] == c) {
          final row = rows[offset++];
          if (row['verse'] is! int || row['text'] is! String) {
            throw const FormatException('Invalid verse data');
          }
          final text = plainMyBibleText(row['text'] as String);
          xml.write(
              '<verse number="${row['verse']}">${_xmlText(text)}</verse>');
          entries++;
          count++;
        }
        if (entries == 0) throw const FormatException('Missing chapter');
        xml.write('</chapter>');
      }
      // Only Psalm 151 may follow the selected 66-book canon's chapters.
      if (offset < rows.length &&
          !(number == 230 &&
              rows.skip(offset).every((r) => r['chapter'] == 151))) {
        throw const FormatException('Unexpected extra chapter');
      }
      xml.write('</book>');
    }
    xml.write('</bible>');
    if (id == 'mbb05' && count != 31046) {
      throw const FormatException('Unexpected MBB05 source entry count');
    }
    final parsed = parseXmlTranslation(
        xml.toString(),
        canon,
        id,
        'Magandang Balita Biblia (2005)',
        'MBB05',
        'Tagalog',
        '$license\n\nSource metadata: ${plainMyBibleText(info['detailed_info']!.replaceAll('<br/>', '\n'))}');
    return Bible([
      for (var b = 0; b < 66; b++)
        BibleBook(parsed.books[b].id, names[b], parsed.books[b].chapters)
    ], parsed.title,
        id: id,
        abbreviation: 'MBB05',
        language: 'Tagalog',
        licenseText: parsed.licenseText);
  } finally {
    db?.close();
    engine.unregisterVirtualFileSystem(fs);
    fs.fileData.clear();
  }
}
