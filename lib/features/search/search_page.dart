import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/bible_search.dart';

class SearchPage extends StatefulWidget {
  final BibleSearch search;
  final String initialQuery;
  final String? initialBook;
  final bool initialPhrase;
  final void Function(String, String?, bool) onOptionsChanged;
  final ValueChanged<SearchHit> onOpen;
  const SearchPage(
      {super.key,
      required this.search,
      required this.onOpen,
      required this.onOptionsChanged,
      this.initialQuery = '',
      this.initialBook,
      this.initialPhrase = false});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final TextEditingController controller;
  String? bookId;
  bool phrase = false;
  bool busy = false;
  String? error;
  SearchResponse response = const SearchResponse([]);
  Timer? debounce;
  int generation = 0;
  int visible = 50;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialQuery);
    bookId = widget.initialBook;
    phrase = widget.initialPhrase;
    if (controller.text.trim().isNotEmpty) schedule(immediate: true);
  }

  void schedule({bool immediate = false}) {
    debounce?.cancel();
    final current = ++generation;
    widget.onOptionsChanged(controller.text, bookId, phrase);
    setState(() {
      busy = controller.text.trim().isNotEmpty;
      error = null;
      response = const SearchResponse([]);
      visible = 50;
    });
    if (!busy) return;
    debounce = Timer(Duration(milliseconds: immediate ? 0 : 250), () async {
      try {
        final result = await widget.search.search(controller.text,
            bookId: bookId,
            phrase: phrase,
            cancelled: () => !mounted || current != generation);
        if (mounted && current == generation) {
          setState(() {
            response = result;
            busy = false;
          });
        }
      } catch (_) {
        if (mounted && current == generation) {
          setState(() {
            busy = false;
            error = 'Search could not finish. Please try again.';
          });
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.search != widget.search) schedule(immediate: true);
  }

  @override
  void dispose() {
    generation++;
    debounce?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: CustomScrollView(
              key: const PageStorageKey('search-scroll'),
              slivers: [
                SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    sliver: SliverToBoxAdapter(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('Search the Word',
                              style:
                                  Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 8),
                          Text(
                              '${widget.search.bible.language} · ${widget.search.bible.title}\nSearches this installed Bible. No internet needed.'),
                          const SizedBox(height: 20),
                          TextField(
                              controller: controller,
                              maxLength: 200,
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                  labelText: 'Words, phrase, or reference',
                                  hintText: 'gugma · Juan 3:16 · John 3:16–18',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: controller.text.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: 'Clear search',
                                          icon: const Icon(Icons.close),
                                          onPressed: () {
                                            controller.clear();
                                            schedule();
                                          })),
                              onChanged: (_) => schedule(),
                              onSubmitted: (_) => schedule(immediate: true)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                              initialValue: bookId ?? '',
                              isExpanded: true,
                              decoration: const InputDecoration(
                                  labelText: 'Book',
                                  border: OutlineInputBorder()),
                              items: [
                                const DropdownMenuItem(
                                    value: '', child: Text('All books')),
                                for (final book in widget.search.bible.books)
                                  DropdownMenuItem(
                                      value: book.id, child: Text(book.name))
                              ],
                              onChanged: (value) {
                                bookId = value == '' ? null : value;
                                schedule(immediate: true);
                              }),
                          const SizedBox(height: 12),
                          Wrap(spacing: 8, children: [
                            ChoiceChip(
                                label: const Text('All words'),
                                selected: !phrase,
                                onSelected: (_) {
                                  phrase = false;
                                  schedule(immediate: true);
                                }),
                            ChoiceChip(
                                label: const Text('Exact phrase'),
                                selected: phrase,
                                onSelected: (_) {
                                  phrase = true;
                                  schedule(immediate: true);
                                }),
                          ]),
                          const SizedBox(height: 8),
                          const Text(
                              'All words matches whole words in any order. Exact phrase matches consecutive words. Case and punctuation are ignored; quotation marks also select a phrase.',
                              style: TextStyle(fontSize: 12)),
                          const SizedBox(height: 20),
                          if (busy) const LinearProgressIndicator(),
                          if (!busy && controller.text.trim().isEmpty)
                            const Text(
                                'Find a passage to pause with. Try “gugma” or Juan 3:16.'),
                          if (error != null) ...[
                            Text(error!),
                            TextButton(
                                onPressed: () => schedule(immediate: true),
                                child: const Text('Retry'))
                          ],
                          if (!busy &&
                              error == null &&
                              controller.text.trim().isNotEmpty)
                            Text(
                                response.message ??
                                    (response.hits.isEmpty
                                        ? 'No verses found. Try fewer words or choose All books.'
                                        : '${response.hits.length} matching passages'),
                                semanticsLabel: response.message ??
                                    '${response.hits.length} matching passages'),
                          const SizedBox(height: 12),
                        ]))),
                SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverList.builder(
                        itemCount: response.hits.length.clamp(0, visible),
                        itemBuilder: (context, index) {
                          final hit = response.hits[index];
                          return Card(
                              child: ListTile(
                                  key: ValueKey('result-${hit.key}'),
                                  contentPadding: const EdgeInsets.all(16),
                                  title: Text(hit.reference,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(hit.verse.text,
                                          style: const TextStyle(
                                              fontFamily: 'SourceSerif4',
                                              fontSize: 18,
                                              height: 1.5),
                                          maxLines: 4,
                                          overflow: TextOverflow.ellipsis)),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    FocusScope.of(context).unfocus();
                                    widget.onOpen(hit);
                                  }));
                        })),
                if (response.hits.length > visible)
                  SliverToBoxAdapter(
                      child: Center(
                          child: TextButton(
                              onPressed: () => setState(() => visible += 50),
                              child: Text(
                                  'Show more (${response.hits.length - visible} remaining)')))),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
              ])));
}
