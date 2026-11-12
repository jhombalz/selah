class BookCategory {
  final String id;
  final String title;
  final bool oldTestament;
  final List<String> books;
  final List<BookCategory> subcategories;
  const BookCategory(this.id, this.title, this.oldTestament, this.books,
      {this.subcategories = const []});
  Set<String> get displayedBooks => {
        ...books,
        for (final category in subcategories) ...category.displayedBooks,
      };
}

// Conventional grouping for the app's 66-book Protestant canon.
const bookCategories = [
  BookCategory('old-law', 'Law', true, ['GEN', 'EXO', 'LEV', 'NUM', 'DEU']),
  BookCategory('old-history', 'History', true, [
    'JOS',
    'JDG',
    'RUT',
    '1SA',
    '2SA',
    '1KI',
    '2KI',
    '1CH',
    '2CH',
    'EZR',
    'NEH',
    'EST'
  ]),
  BookCategory('old-poetry', 'Poetry & Wisdom', true,
      ['JOB', 'PSA', 'PRO', 'ECC', 'SNG']),
  BookCategory(
      'old-major', 'Major Prophets', true, ['ISA', 'JER', 'LAM', 'EZK', 'DAN']),
  BookCategory('old-minor', 'Minor Prophets', true, [
    'HOS',
    'JOL',
    'AMO',
    'OBA',
    'JON',
    'MIC',
    'NAM',
    'HAB',
    'ZEP',
    'HAG',
    'ZEC',
    'MAL'
  ]),
  BookCategory('new-gospels', 'Gospels', false, ['MAT', 'MRK', 'LUK', 'JHN']),
  // The Gospel books are also cross-listed inside History, while canonical
  // membership above remains unique for counts and the current-book anchor.
  BookCategory('new-history', 'History', false, [
    'ACT'
  ], subcategories: [
    BookCategory('history-jesus', 'History of Jesus (Gospels)', false,
        ['MAT', 'MRK', 'LUK', 'JHN']),
    BookCategory(
        'history-church', 'History of the Church (Acts)', false, ['ACT']),
  ]),
  BookCategory('new-pauline', 'Pauline Letters', false, [
    'ROM',
    '1CO',
    '2CO',
    'GAL',
    'EPH',
    'PHP',
    'COL',
    '1TH',
    '2TH',
    '1TI',
    '2TI',
    'TIT',
    'PHM'
  ]),
  BookCategory('new-general', 'General Letters', false,
      ['HEB', 'JAS', '1PE', '2PE', '1JN', '2JN', '3JN', 'JUD']),
  BookCategory('new-prophecy', 'Prophecy', false, ['REV']),
];
