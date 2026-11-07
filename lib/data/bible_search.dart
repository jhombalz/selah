import 'book_names.dart';
import 'bible.dart';

class SearchHit {
  final int bookIndex;
  final int chapterIndex;
  final BibleBook book;
  final BibleVerse verse;
  const SearchHit(this.bookIndex, this.chapterIndex, this.book, this.verse);
  String get key => '${book.id}.${chapterIndex + 1}.${verse.number}';
  String get reference => '${book.name} ${chapterIndex + 1}:${verse.number}';
}

class SearchResponse {
  final List<SearchHit> hits;
  final String? message;
  const SearchResponse(this.hits, [this.message]);
}

class _IndexedVerse {
  final SearchHit hit;
  final String text;
  const _IndexedVerse(this.hit, this.text);
}

/// Searches bundled Scripture only. Chunking yields to the UI on mobile and web.
class BibleSearch {
  final Bible bible;
  Future<List<_IndexedVerse>>? _index;
  BibleSearch(this.bible);

  static String normalize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\u00c0-\u024f]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');

  Future<List<_IndexedVerse>> _buildIndex() async {
    final entries = <_IndexedVerse>[];
    for (int b = 0; b < bible.books.length; b++) {
      final book = bible.books[b];
      for (int c = 0; c < book.chapters.length; c++) {
        for (final verse in book.chapters[c]) {
          entries.add(_IndexedVerse(
              SearchHit(b, c, book, verse), ' ${normalize(verse.text)} '));
          if (entries.length % 256 == 0) {
            await Future<void>.delayed(Duration.zero);
          }
        }
      }
    }
    return entries;
  }

  Future<SearchResponse> search(String query,
      {String? bookId, bool phrase = false, bool Function()? cancelled}) async {
    query = query.trim();
    if (query.isEmpty) return const SearchResponse([]);
    if (query.length > 200) {
      return const SearchResponse(
          [], 'Please keep your search under 200 characters.');
    }
    if (RegExp(r'^\d+\s*:').hasMatch(query)) {
      return const SearchResponse(
          [], 'Include a book name, for example Juan 3:16.');
    }
    final reference =
        RegExp(r'^(.+?)\s*(\d+)\s*(?::\s*(\d+)\s*(?:[-–]\s*(\d+))?)?$')
            .firstMatch(query);
    if (reference != null) return _reference(reference, bookId);
    final normalized = normalize(query);
    if (normalized.isEmpty) {
      return const SearchResponse(
          [], 'Enter a word, phrase, or Scripture reference.');
    }
    final exact = phrase ||
        (query.startsWith('"') && query.endsWith('"')) ||
        (query.startsWith('“') && query.endsWith('”'));
    final terms = normalized.split(' ').toSet();
    final entries = await (_index ??= _buildIndex());
    final hits = <SearchHit>[];
    for (int i = 0; i < entries.length; i++) {
      if (i % 512 == 0) {
        await Future<void>.delayed(Duration.zero);
        if (cancelled?.call() ?? false) return const SearchResponse([]);
      }
      final entry = entries[i];
      if (bookId != null && entry.hit.book.id != bookId) continue;
      if (exact
          ? entry.text.contains(' $normalized ')
          : terms.every((term) => entry.text.contains(' $term '))) {
        hits.add(entry.hit);
      }
    }
    return SearchResponse(hits);
  }

  SearchResponse _reference(RegExpMatch match, String? filter) {
    final name = normalize(match[1]!);
    int bookIndex = -1;
    for (int i = 0; i < bible.books.length; i++) {
      if ([
        bible.books[i].name,
        cebuanoBookNames[i],
        bible.books[i].id,
        englishBookNames[i],
        ...?_aliases[bible.books[i].id]
      ].any((alias) =>
          normalize(alias).replaceAll(' ', '') == name.replaceAll(' ', ''))) {
        bookIndex = i;
        break;
      }
    }
    if (bookIndex < 0) {
      return const SearchResponse([],
          'Book not recognized. Try a Cebuano or English book name, such as Juan or John.');
    }
    final book = bible.books[bookIndex];
    if (filter != null && filter != book.id) {
      return const SearchResponse([],
          'This reference is outside the selected book. Choose All books to find it.');
    }
    final chapter = int.tryParse(match[2]!) ?? 0;
    if (chapter < 1 || chapter > book.chapters.length) {
      return SearchResponse(
          [], '${book.name} has ${book.chapters.length} chapters.');
    }
    final verses = book.chapters[chapter - 1];
    final from = int.tryParse(match[3] ?? '');
    final to = match[4] == null ? from : int.tryParse(match[4]!);
    if (match[3] != null &&
        (from == null ||
            to == null ||
            from < 1 ||
            to < from ||
            to > int.parse(verses.last.number.split('-').last))) {
      return const SearchResponse(
          [], 'That verse or verse range is not available in this chapter.');
    }
    final hits = <SearchHit>[];
    for (final verse in verses) {
      final range = verse.number.split('-').map(int.parse).toList();
      if (from == null || (range.last >= from && range.first <= to!)) {
        hits.add(SearchHit(bookIndex, chapter - 1, book, verse));
      }
    }
    return SearchResponse(
        hits,
        hits.isEmpty
            ? 'This verse is not present as a separate passage in this edition.'
            : null);
  }
}

const _aliases = <String, List<String>>{
  'GEN': ['Gen'],
  'EXO': ['Ex'],
  'PSA': ['Psalm', 'Ps'],
  'PRO': ['Prov'],
  'SNG': ['Song of Songs'],
  'MAT': ['Matt', 'Mt'],
  'MRK': ['Mk'],
  'LUK': ['Lk'],
  'JHN': ['Jn'],
  'ROM': ['Rom'],
  '1CO': ['1 Cor'],
  '2CO': ['2 Cor'],
  '1JN': ['1 Jn'],
  '2JN': ['2 Jn'],
  '3JN': ['3 Jn'],
};
