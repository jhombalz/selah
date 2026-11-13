import 'dart:convert';
import 'bible.dart';
import 'book_names.dart';

const repositoryBookIds = [
  'gn',
  'ex',
  'lv',
  'nm',
  'dt',
  'js',
  'jz',
  'rt',
  '1sm',
  '2sm',
  '1rs',
  '2rs',
  '1cr',
  '2cr',
  'ed',
  'ne',
  'et',
  'jó',
  'sl',
  'pv',
  'ec',
  'ct',
  'is',
  'jr',
  'lm',
  'ez',
  'dn',
  'os',
  'jl',
  'am',
  'ob',
  'jn',
  'mq',
  'na',
  'hc',
  'sf',
  'ag',
  'zc',
  'ml',
  'mt',
  'mc',
  'lc',
  'jo',
  'atos',
  'rm',
  '1co',
  '2co',
  'gl',
  'ef',
  'fp',
  'cl',
  '1ts',
  '2ts',
  '1tm',
  '2tm',
  'tt',
  'fm',
  'hb',
  'tg',
  '1pe',
  '2pe',
  '1jo',
  '2jo',
  '3jo',
  'jd',
  'ap'
];

// Array indices do not retain omissions in the supplied JSON files.
const omittedRepositoryVerses = <String, List<int>>{
  'MAT.17': [21],
  'MAT.18': [11],
  'MAT.23': [14],
  'MRK.7': [16],
  'MRK.9': [44, 46],
  'MRK.11': [26],
  'MRK.15': [28],
  'LUK.17': [36],
  'LUK.23': [17],
  'JHN.5': [4],
  'ACT.8': [37],
  'ACT.15': [34],
  'ACT.24': [7],
  'ACT.28': [29],
  'ROM.16': [24],
};
const nltNumberLabels = <String, List<String>>{
  'NUM.1': [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    '11',
    '12',
    '13',
    '14',
    '15',
    '16',
    '17',
    '18',
    '19',
    '20-21',
    '44',
    '45',
    '46',
    '47',
    '48',
    '49',
    '50',
    '51',
    '52',
    '53',
    '54'
  ],
  'NUM.2': [
    '1',
    '2',
    '3-4',
    '9',
    '10-11',
    '16',
    '17',
    '18-19',
    '24',
    '25-26',
    '31',
    '32',
    '33',
    '34'
  ],
};
const nltRepositoryWarning =
    'The supplied NLT file omits table text in Numbers 1–2, including Numbers 1:22–43 and parts of Numbers 2. Verse labels are preserved; missing wording has not been invented or replaced with another translation.';

/// The raw bytes must be checked against the pinned hash before this conversion.
Bible parseRepositoryTranslation(String source, Bible canon, String id,
    String title, String abbreviation, String license) {
  final data = jsonDecode(source.replaceFirst('\ufeff', ''));
  if (data is! List || data.length != 66 || canon.books.length != 66) {
    throw const FormatException('The source must contain all 66 books.');
  }
  var total = 0;
  final books = <BibleBook>[];
  for (var b = 0; b < 66; b++) {
    final raw = data[b];
    if (raw is! Map ||
        raw['abbrev'] != repositoryBookIds[b] ||
        raw['chapters'] is! List ||
        (raw['chapters'] as List).length != canon.books[b].chapters.length) {
      throw FormatException(
          'Invalid book order or chapter count at book ${b + 1}.');
    }
    final chapters = <List<BibleVerse>>[];
    final rawChapters = raw['chapters'] as List;
    for (var c = 0; c < rawChapters.length; c++) {
      final rows = rawChapters[c];
      if (rows is! List || rows.isEmpty || rows.length > 200) {
        throw const FormatException('Invalid chapter.');
      }
      final ref = '${canon.books[b].id}.${c + 1}';
      final labels = id == 'nlt' ? nltNumberLabels[ref] : null;
      if (labels != null && labels.length != rows.length) {
        throw const FormatException('Unexpected grouped verse data.');
      }
      final verses = <BibleVerse>[];
      var number = 1;
      for (var v = 0; v < rows.length; v++) {
        final text = rows[v];
        if (text is! String ||
            text.trim().isEmpty ||
            text.length > 50000 ||
            text.contains('\u0000')) {
          throw const FormatException('Invalid verse text.');
        }
        while (omittedRepositoryVerses[ref]?.contains(number) ?? false) {
          number++;
        }
        verses.add(BibleVerse(labels?[v] ?? '$number', text));
        number++;
        total++;
      }
      chapters.add(verses);
    }
    books.add(BibleBook(canon.books[b].id, englishBookNames[b], chapters));
  }
  if (total != (id == 'niv' ? 31087 : 31045)) {
    throw const FormatException(
        'Unexpected verse count for the verified source.');
  }
  return Bible(books, title,
      id: id,
      abbreviation: abbreviation,
      language: 'English',
      licenseText: license);
}
