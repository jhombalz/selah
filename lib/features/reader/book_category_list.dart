import 'package:flutter/material.dart';
import '../../data/bible.dart';
import '../../data/book_categories.dart';

class BookCategoryList extends StatelessWidget {
  final Bible bible;
  final bool oldTestament;
  final String query;
  final int currentBook;
  final Set<String> expanded;
  final ScrollController controller;
  final GlobalKey currentAnchor;
  final bool Function(int) matchesBook;
  final void Function(String, bool) onExpand;
  final ValueChanged<int> onPick;
  const BookCategoryList(
      {super.key,
      required this.bible,
      required this.oldTestament,
      required this.query,
      required this.currentBook,
      required this.expanded,
      required this.controller,
      required this.currentAnchor,
      required this.matchesBook,
      required this.onExpand,
      required this.onPick});

  bool matchesCategory(BookCategory category) =>
      bible.books.asMap().entries.any((entry) =>
          category.displayedBooks.contains(entry.value.id) &&
          matchesBook(entry.key));

  Widget category(
      BuildContext context, BookCategory group, Set<String> canonical) {
    final searching = query.trim().isNotEmpty;
    final current = bible.books[currentBook].id;
    return Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ExpansionTile(
          key: PageStorageKey('book-category-${group.id}-$query'),
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          leading: Icon(Icons.auto_stories_outlined,
              size: 22, color: Theme.of(context).colorScheme.primary),
          initiallyExpanded: searching ||
              expanded.contains(group.id) ||
              group.books.contains(current),
          onExpansionChanged: (value) => onExpand(group.id, value),
          title: Semantics(
              header: true,
              child: Text(group.title,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          subtitle: Text(group.subcategories.isNotEmpty
              ? 'Jesus and the early Church'
              : searching
                  ? (group.oldTestament ? 'Old Testament' : 'New Testament')
                  : '${group.books.length} ${group.books.length == 1 ? 'book' : 'books'}'),
          children: group.subcategories.isNotEmpty
              ? [
                  for (final child in group.subcategories)
                    if (matchesCategory(child))
                      category(context, child, canonical)
                ]
              : [
                  for (var i = 0; i < bible.books.length; i++)
                    if (group.books.contains(bible.books[i].id) &&
                        matchesBook(i))
                      book(
                          context,
                          i,
                          canonical.contains(bible.books[i].id)
                              ? null
                              : group.id)
                ],
        ));
  }

  Widget book(BuildContext context, int index, String? alias) {
    final item = bible.books[index];
    return Padding(
        key: index == currentBook && alias == null ? currentAnchor : null,
        padding: const EdgeInsets.only(bottom: 4),
        child: ListTile(
          key: ValueKey(alias == null
              ? 'pick-book-${item.id}'
              : 'pick-book-$alias-${item.id}'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          minTileHeight: 60,
          title: Text(item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: index == currentBook
                      ? FontWeight.w600
                      : FontWeight.w400)),
          subtitle: Text('${item.chapters.length} chapters',
              style: const TextStyle(fontSize: 12)),
          selected: index == currentBook,
          selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
          selectedColor: Theme.of(context).colorScheme.onSurface,
          trailing: Icon(
              index == currentBook
                  ? Icons.check_circle_rounded
                  : Icons.chevron_right_rounded,
              size: index == currentBook ? 22 : 20),
          onTap: () {
            FocusScope.of(context).unfocus();
            onPick(index);
          },
        ));
  }

  @override
  Widget build(BuildContext context) {
    final groups = bookCategories
        .where((group) =>
            (query.trim().isNotEmpty || group.oldTestament == oldTestament) &&
            matchesCategory(group))
        .toList();
    if (groups.isEmpty) {
      return const Center(
          child: Text('No books found. Try another book name.'));
    }
    return SingleChildScrollView(
        key: const PageStorageKey('passage-picker-books-scroll'),
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(children: [
          for (final group in groups)
            category(context, group, group.books.toSet())
        ]));
  }
}
