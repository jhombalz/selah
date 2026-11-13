import 'package:xml/xml.dart';
import 'bible.dart';
import 'book_names.dart';
import 'repository_translation.dart';

/// Blank numbered entries are continuations of the preceding passage, except
/// known textual omissions. Missing nodes are kept as gaps, never renumbered.
Bible parseXmlTranslation(String source, Bible canon, String id, String title,
    String abbreviation, String language, String license) {
  if (RegExp(r'<!\s*(?:DOCTYPE|ENTITY)', caseSensitive: false)
      .hasMatch(source)) {
    throw const FormatException(
        'DTD and entity declarations are not supported.');
  }
  final document = XmlDocument.parse(source);
  if (document.rootElement.name.local != 'bible') {
    throw const FormatException('Unexpected XML Bible root.');
  }
  final rawBooks = document.rootElement.findAllElements('book').toList();
  if (rawBooks.length != 66 || canon.books.length != 66) {
    throw const FormatException('Expected all 66 books.');
  }
  final books = <BibleBook>[];
  var sourceEntries = 0, nonempty = 0;
  for (var b = 0; b < 66; b++) {
    final raw = rawBooks[b];
    if (raw.getAttribute('number') != '${b + 1}') {
      throw const FormatException('Invalid book order.');
    }
    final rawChapters = raw.findElements('chapter').toList();
    if (rawChapters.length != canon.books[b].chapters.length) {
      throw const FormatException('Invalid chapter count.');
    }
    final chapters = <List<BibleVerse>>[];
    for (var c = 0; c < rawChapters.length; c++) {
      final chapter = rawChapters[c];
      if (chapter.getAttribute('number') != '${c + 1}') {
        throw const FormatException('Invalid chapter order.');
      }
      final ref = '${canon.books[b].id}.${c + 1}';
      final omitted = {
        ...?(omittedRepositoryVerses[ref]),
        if (ref == 'MAT.21') 44
      };
      final verses = <BibleVerse>[];
      int start = 0, end = 0, last = 0;
      String? text;
      void flush() {
        if (text != null) {
          verses
              .add(BibleVerse(start == end ? '$start' : '$start-$end', text!));
        }
        text = null;
      }

      final entries = chapter.findElements('verse').toList();
      if (entries.isEmpty || entries.length > 200) {
        throw const FormatException('Invalid chapter verse data.');
      }
      for (final entry in entries) {
        final number = int.tryParse(entry.getAttribute('number') ?? '');
        if (number == null || number <= last || number > 200) {
          throw const FormatException('Invalid or duplicate verse number.');
        }
        if (entry.childElements.isNotEmpty) {
          throw const FormatException('Unexpected nested verse markup.');
        }
        sourceEntries++;
        last = number;
        final value = entry.innerText;
        if (value.trim().isEmpty) {
          if (text != null && number == end + 1 && !omitted.contains(number)) {
            end = number;
          } else {
            flush();
          }
          continue;
        }
        if (value.length > 50000 || value.contains('\u0000')) {
          throw const FormatException('Invalid verse text.');
        }
        flush();
        start = end = number;
        text = value;
        nonempty++;
      }
      flush();
      if (verses.isEmpty) {
        throw const FormatException('The source contains an empty chapter.');
      }
      chapters.add(verses);
    }
    books.add(BibleBook(
        canon.books[b].id,
        language == 'Cebuano' ? cebuanoBookNames[b] : englishBookNames[b],
        chapters));
  }
  if (id == 'mbbceb99' && (sourceEntries != 30748 || nonempty != 30557)) {
    throw const FormatException(
        'Unexpected entry counts for the verified MBBCEB99 source.');
  }
  final status = document.rootElement.getAttribute('status');
  final link = document.rootElement.getAttribute('link');
  return Bible(books, title,
      id: id,
      abbreviation: abbreviation,
      language: language,
      licenseText:
          '$license${status == null ? '' : '\n\nSource copyright notice: $status'}${link == null ? '' : '\nSource attribution: $link'}');
}
