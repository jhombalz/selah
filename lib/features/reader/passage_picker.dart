import 'package:flutter/material.dart';
import '../../data/bible.dart';
import '../../data/book_categories.dart';
import '../../data/book_names.dart';
import '../common/selah_dialog.dart';
import 'book_category_list.dart';

class PassageSelection {
  final int book;
  final int chapter;
  const PassageSelection(this.book, this.chapter);
}

class PassagePicker extends StatefulWidget {
  final Bible bible;
  final int currentBook;
  final int currentChapter;
  const PassagePicker(
      {super.key,
      required this.bible,
      required this.currentBook,
      required this.currentChapter});

  static Future<PassageSelection?> open(BuildContext context,
      {required Bible bible,
      required int currentBook,
      required int currentChapter}) {
    final picker = PassagePicker(
        bible: bible, currentBook: currentBook, currentChapter: currentChapter);
    if (MediaQuery.sizeOf(context).width < 840) {
      return Navigator.of(context).push<PassageSelection>(
          MaterialPageRoute(fullscreenDialog: true, builder: (_) => picker));
    }
    return showDialog<PassageSelection>(
        context: context,
        builder: (context) => SelahDialog(
            contentPadding: EdgeInsets.zero,
            content: SizedBox(
                width: 600,
                height: MediaQuery.sizeOf(context).height * .8,
                child: picker)));
  }

  @override
  State<PassagePicker> createState() => _PassagePickerState();
}

class _PassagePickerState extends State<PassagePicker> {
  int? selectedBook;
  String query = '';
  bool searching = false;
  late final ScrollController booksScroll;
  late bool oldTestament;
  final expandedCategories = <String>{};
  final currentBookAnchor = GlobalKey();

  @override
  void initState() {
    super.initState();
    booksScroll = ScrollController();
    final category = bookCategories.firstWhere((category) =>
        category.books.contains(widget.bible.books[widget.currentBook].id));
    oldTestament = category.oldTestament;
    expandedCategories.add(category.id);
    revealCurrentBook();
  }

  @override
  void dispose() {
    booksScroll.dispose();
    super.dispose();
  }

  void back() {
    if (selectedBook == null) {
      Navigator.pop(context);
    } else {
      setState(() => selectedBook = null);
    }
  }

  void revealCurrentBook() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final anchor = currentBookAnchor.currentContext;
      if (mounted && anchor != null) {
        Scrollable.ensureVisible(anchor, alignment: .2);
      }
    });
  }

  void changeTestament(bool value) {
    final currentId = widget.bible.books[widget.currentBook].id;
    final group = bookCategories.firstWhere(
        (category) =>
            category.oldTestament == value &&
            category.books.contains(currentId),
        orElse: () => bookCategories
            .firstWhere((category) => category.oldTestament == value));
    setState(() {
      oldTestament = value;
      expandedCategories
        ..clear()
        ..add(group.id);
    });
    if (booksScroll.hasClients) booksScroll.jumpTo(0);
    revealCurrentBook();
  }

  bool matchesBook(int index) {
    final text = query.trim().toLowerCase();
    return [
      widget.bible.books[index].name,
      widget.bible.books[index].id,
      englishBookNames[index],
      cebuanoBookNames[index]
    ].any((name) => name.toLowerCase().contains(text));
  }

  Widget categorizedBooks(BuildContext context) => BookCategoryList(
      bible: widget.bible,
      oldTestament: oldTestament,
      query: query,
      currentBook: widget.currentBook,
      expanded: expandedCategories,
      controller: booksScroll,
      currentAnchor: currentBookAnchor,
      matchesBook: matchesBook,
      onExpand: (id, expanded) {
        if (query.trim().isNotEmpty) return;
        expanded ? expandedCategories.add(id) : expandedCategories.remove(id);
      },
      onPick: (index) => setState(() => selectedBook = index));

  @override
  Widget build(BuildContext context) {
    final books = widget.bible.books;
    return PopScope(
      canPop: selectedBook == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && mounted) setState(() => selectedBook = null);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
              tooltip:
                  selectedBook == null ? 'Back to reading' : 'Back to books',
              onPressed: back,
              icon: const Icon(Icons.arrow_back)),
          title:
              Text(selectedBook == null ? 'Books' : books[selectedBook!].name),
          actions: [
            if (selectedBook == null)
              IconButton(
                  tooltip: 'Find a book',
                  icon: Icon(searching ? Icons.search_off : Icons.search),
                  onPressed: () {
                    setState(() {
                      searching = !searching;
                      query = '';
                    });
                    if (booksScroll.hasClients) {
                      booksScroll.jumpTo(0);
                    }
                    if (!searching) revealCurrentBook();
                  }),
            IconButton(
                tooltip: 'Close passage picker',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close)),
          ],
        ),
        body: SafeArea(
            top: false,
            child: Column(children: [
              if (selectedBook == null && searching)
                Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                          hintText: 'Find a book',
                          prefixIcon: Icon(Icons.search),
                          filled: true,
                          border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius:
                                  BorderRadius.all(Radius.circular(16)))),
                      onChanged: (value) {
                        if (booksScroll.hasClients) booksScroll.jumpTo(0);
                        setState(() => query = value);
                      },
                    )),
              if (selectedBook == null && query.trim().isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<bool>(
                        style: SegmentedButton.styleFrom(
                            side: BorderSide.none,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerLow,
                            selectedBackgroundColor:
                                Theme.of(context).colorScheme.primaryContainer,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 14)),
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                              value: true, label: Text('Old Testament')),
                          ButtonSegment(
                              value: false, label: Text('New Testament'))
                        ],
                        selected: {oldTestament},
                        onSelectionChanged: (value) =>
                            changeTestament(value.single),
                      )),
                ),
              if (selectedBook == null)
                Expanded(child: categorizedBooks(context))
              else
                Expanded(
                    child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(20)),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(books[selectedBook!].name,
                                            style: const TextStyle(
                                                fontFamily: 'SourceSerif4',
                                                fontSize: 28)),
                                        const SizedBox(height: 6),
                                        Text(
                                            '${books[selectedBook!].chapters.length} chapters · ${widget.bible.abbreviation}',
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant)),
                                      ])),
                              const SizedBox(height: 20),
                              const Text('Choose a chapter',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 16),
                              Expanded(
                                  child: GridView.builder(
                                      key: PageStorageKey(
                                          'passage-picker-chapters-${books[selectedBook!].id}'),
                                      gridDelegate:
                                          SliverGridDelegateWithMaxCrossAxisExtent(
                                              maxCrossAxisExtent: 84 *
                                                  MediaQuery.textScalerOf(context)
                                                      .scale(1)
                                                      .clamp(1, 1.8),
                                              mainAxisSpacing: 10,
                                              crossAxisSpacing: 10),
                                      itemCount:
                                          books[selectedBook!].chapters.length,
                                      itemBuilder: (context, index) => FilledButton(
                                          key: ValueKey(
                                              'pick-chapter-${index + 1}'),
                                          style: FilledButton.styleFrom(
                                              padding: EdgeInsets.zero,
                                              foregroundColor: selectedBook ==
                                                          widget.currentBook &&
                                                      index == widget.currentChapter
                                                  ? Theme.of(context).colorScheme.onPrimary
                                                  : Theme.of(context).colorScheme.onSurface,
                                              backgroundColor: selectedBook == widget.currentBook && index == widget.currentChapter ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerLow,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                                          onPressed: () => Navigator.pop(context, PassageSelection(selectedBook!, index)),
                                          child: Semantics(selected: selectedBook == widget.currentBook && index == widget.currentChapter, label: 'Chapter ${index + 1}', child: Text('${index + 1}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)))))),
                            ]))),
            ])),
      ),
    );
  }
}
