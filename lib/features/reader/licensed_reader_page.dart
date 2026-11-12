import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/bible.dart';
import '../../data/book_names.dart';
import '../../data/licensed_bible.dart';
import '../../data/scripture_range.dart';
import '../../data/user_database.dart';
import '../common/selah_dialog.dart';
import '../../data/growth_entry.dart';
import '../growth/growth_share.dart';
import 'chapter_completion_card.dart';
import 'passage_picker.dart';
import 'passage_selection_layer.dart';
import 'reader_toolbar.dart';
import 'reader_preferences_sheet.dart';
import 'chapter_navigation.dart';
import 'reader_scroll_intent.dart';

class LicensedReaderPage extends StatefulWidget {
  final LicensedEdition edition;
  final Bible canon;
  final UserDatabase database;
  final String initialReference;
  final ValueChanged<bool>? onReady;
  final LicensedBibleRepository? repository;
  final VoidCallback? onTranslation;
  final VoidCallback? onSearch;
  final ValueChanged<bool>? onControlsVisible;
  final ValueChanged<String>? onLocation;
  final VoidCallback? onDataChanged;
  final bool preferSavedReference;
  final bool initialControlsVisible;
  const LicensedReaderPage(
      {super.key,
      required this.edition,
      required this.canon,
      required this.database,
      this.initialReference = 'GEN.1',
      this.onReady,
      this.repository,
      this.onTranslation,
      this.onSearch,
      this.onControlsVisible,
      this.onLocation,
      this.onDataChanged,
      this.preferSavedReference = true,
      this.initialControlsVisible = true});
  @override
  State<LicensedReaderPage> createState() => _LicensedReaderPageState();
}

class _LicensedReaderPageState extends State<LicensedReaderPage>
    with WidgetsBindingObserver {
  late final repository =
      widget.repository ?? LicensedBibleRepository(widget.database);
  final scroll = ScrollController(), anchors = <String, GlobalKey>{};
  late final template = Bible([
    for (var i = 0; i < widget.canon.books.length; i++)
      BibleBook(
          widget.canon.books[i].id,
          englishBookNames[i],
          List.generate(
              widget.canon.books[i].chapters.length, (_) => <BibleVerse>[]))
  ], widget.edition.name);
  LicensedChapter? content;
  UserData user = const UserData();
  int book = 0, chapter = 0, generation = 0;
  double fontSize = 21;
  bool loading = true, writing = false;
  late bool controlsVisible = widget.initialControlsVisible;
  late bool revealAtTopOnly = !widget.initialControlsVisible;
  final scrollIntent = ReaderScrollIntent();

  void showControls(bool value) {
    if (controlsVisible == value) return;
    setState(() => controlsVisible = value);
    widget.onControlsVisible?.call(value);
  }

  Future<void> preferences() => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
          maxWidth: 560, maxHeight: MediaQuery.sizeOf(context).height * .9),
      builder: (sheetContext) => ReaderPreferencesSheet(
              fontSize: fontSize,
              paragraphs: false,
              redLetters: false,
              showFormatting: false,
              onParagraphs: (_) {},
              onRedLetters: (_) {},
              onSize: (value, persist) {
                setState(() => fontSize = value);
                if (persist) {
                  unawaited(mutate(() =>
                      widget.database.setPreferences({'fontSize': '$value'})));
                }
              },
              extraActions: [
                ListTile(
                    leading: const Icon(Icons.refresh),
                    title: const Text('Refresh chapter'),
                    onTap: loading
                        ? null
                        : () {
                            Navigator.pop(sheetContext);
                            unawaited(load(refresh: true));
                          }),
                ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Clear saved online chapters'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      unawaited(clearCache());
                    }),
              ]));
  String? error, selection;
  Timer? expiry;
  String get reference => '${template.books[book].id}.${chapter + 1}';
  String get label => '${template.books[book].name} ${chapter + 1}';
  String get preference => 'licensedLast_${widget.edition.id}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(start());
  }

  Future<void> start() async {
    try {
      final data = await widget.database.load();
      if (!mounted) return;
      user = data;
      fontSize = (double.tryParse(data.preferences['fontSize'] ?? '') ?? 21)
          .clamp(16, 32);
      final parts = ((widget.preferSavedReference
                  ? data.preferences[preference]
                  : null) ??
              widget.initialReference)
          .split('.');
      final index = template.books.indexWhere((b) => b.id == parts.first);
      final number = parts.length == 2 ? int.tryParse(parts[1]) : null;
      if (index >= 0 &&
          number != null &&
          number >= 1 &&
          number <= template.books[index].chapters.length) {
        book = index;
        chapter = number - 1;
      }
      await load();
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Reading data could not be opened. Please retry.';
        });
      }
    }
    if (!mounted) return;
    expiry = Timer.periodic(const Duration(minutes: 1), (_) {
      if (content != null && !content!.fresh(repository.now()) && !loading) {
        unawaited(load());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !loading) unawaited(load());
  }

  Future<void> load({bool refresh = false}) async {
    final request = ++generation;
    widget.onReady?.call(false);
    setState(() {
      loading = true;
      error = null;
      content = null;
      selection = null;
      anchors.clear();
    });
    try {
      final result = await repository.load(
          widget.edition, template.books[book].id, chapter + 1,
          refresh: refresh);
      if (!mounted || request != generation) return;
      // Record only reference and personal progress; Scripture stays in its own cache.
      await widget.database.setPreferences({preference: reference});
      await widget.database.visit(reference);
      final data = await widget.database.load();
      if (!mounted || request != generation) return;
      setState(() {
        content = result;
        loading = false;
        user = data;
      });
      widget.onReady?.call(true);
      widget.onLocation?.call(reference);
      widget.onDataChanged?.call();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scroll.hasClients) scroll.jumpTo(0);
      });
    } catch (e) {
      if (mounted && request == generation) {
        setState(() {
          loading = false;
          error = e is StateError
              ? e.message
              : e is FormatException
                  ? e.message
                  : 'This chapter could not be opened. Check your connection and try again.';
        });
      }
    }
  }

  void move(int direction) {
    revealAtTopOnly = !controlsVisible;
    scrollIntent.reset();
    if (loading || writing) return;
    var b = book, c = chapter + direction;
    if (c < 0) {
      if (b == 0) return;
      b--;
      c = template.books[b].chapters.length - 1;
    }
    if (c >= template.books[b].chapters.length) {
      b++;
      c = 0;
    }
    if (b >= template.books.length) return;
    book = b;
    chapter = c;
    unawaited(load());
  }

  Future<void> pick() async {
    final result = await PassagePicker.open(context,
        bible: template, currentBook: book, currentChapter: chapter);
    if (result != null && mounted) {
      book = result.book;
      chapter = result.chapter;
      await load();
    }
  }

  Future<void> mutate(Future<void> Function() action) async {
    if (writing) return;
    setState(() => writing = true);
    try {
      await action();
      final data = await widget.database.load();
      if (mounted) setState(() => user = data);
      widget.onDataChanged?.call();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Your change could not be saved. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => writing = false);
    }
  }

  String display(String ref) {
    final r = ScriptureRange.parse(ref);
    return '${template.books.firstWhere((b) => b.id == r.book).name} ${r.chapter}:${r.start}${r.end == r.start ? '' : '–${r.end}'}';
  }

  Future<void> note(String ref) async {
    final controller = TextEditingController(text: user.notes[ref]);
    var saving = false;
    final route = DialogRoute<void>(
        context: context,
        builder: (context) => SelahDialog(
                title: Text('Your reflection · ${display(ref)}'),
                content: TextField(
                    controller: controller,
                    minLines: 4,
                    maxLines: 8,
                    maxLength: 100000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                        hintText: 'What speaks to you in this passage?')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () async {
                        if (saving) return;
                        saving = true;
                        final value = controller.text.trim();
                        try {
                          await widget.database.setNote(
                              ref, value.isEmpty ? null : value,
                              sourceTranslation: widget.edition.id);
                          final data = await widget.database.load();
                          if (mounted) setState(() => user = data);
                          widget.onDataChanged?.call();
                          if (context.mounted) Navigator.pop(context);
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Could not save. Your reflection is still here; please retry.')));
                          }
                        } finally {
                          saving = false;
                        }
                      },
                      child: const Text('Save note'))
                ]));
    await Navigator.of(context).push(route);
    await route.completed;
    controller.dispose();
  }

  void changeFont(int delta) {
    setState(() => fontSize = (fontSize + delta).clamp(16, 32));
    unawaited(mutate(
        () => widget.database.setPreferences({'fontSize': '$fontSize'})));
  }

  Future<void> actions(String ref) async {
    if (writing) return;
    final bookmarked = user.bookmarks.contains(ref);
    final result = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ListTile(
                      title: Text(display(ref)),
                      subtitle: Text(widget.edition.abbreviation)),
                  ListTile(
                      leading: Icon(bookmarked
                          ? Icons.bookmark_remove_outlined
                          : Icons.bookmark_add_outlined),
                      title: Text(
                          bookmarked ? 'Remove bookmark' : 'Bookmark passage'),
                      onTap: () => Navigator.pop(context, 'bookmark')),
                  ListTile(
                      leading: const Icon(Icons.edit_note),
                      title: const Text('Write a note'),
                      onTap: () => Navigator.pop(context, 'note')),
                  ListTile(
                      leading: const Icon(Icons.ios_share),
                      title: const Text('Share passage'),
                      onTap: () => Navigator.pop(context, 'share')),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Wrap(spacing: 10, children: [
                        for (final color in [
                          0xffffc107,
                          0xff66bb6a,
                          0xff42a5f5,
                          0xffef9a9a
                        ])
                          IconButton(
                              tooltip: 'Highlight passage',
                              style: IconButton.styleFrom(
                                  backgroundColor: Color(color)),
                              onPressed: () => Navigator.pop(context, '$color'),
                              icon: const Icon(Icons.format_color_fill,
                                  color: Colors.black87)),
                        IconButton(
                            tooltip: 'Remove highlight',
                            onPressed: () => Navigator.pop(context, 'clear'),
                            icon: const Icon(Icons.format_color_reset)),
                      ])),
                ]))));
    if (!mounted) return;
    if (result == 'bookmark') {
      await mutate(() => widget.database.setBookmark(ref, !bookmarked));
    } else if (result == 'note') {
      await note(ref);
    } else if (result == 'share' &&
        content != null &&
        content!.fresh(repository.now())) {
      final entry = GrowthEntry.create(
          kind: 'session',
          title: 'Scripture',
          translation: widget.edition.id,
          reference: ref);
      entry.reflection = user.notes.entries
          .where((e) => Bible.overlaps(ref, e.key))
          .map((e) => e.value)
          .join('\n\n');
      await previewGrowthShare(
          context,
          licensedBibleMetadata(widget.canon, widget.edition, content: content),
          entry);
    } else if (result != null) {
      final updated = recolorPassage(
          user.highlights, ref, result == 'clear' ? null : int.parse(result));
      await mutate(() => widget.database.transaction(() async {
            for (final key
                in user.highlights.keys.where((k) => !updated.containsKey(k))) {
              await widget.database.setHighlight(key, null);
            }
            for (final entry in updated.entries) {
              await widget.database.setHighlight(entry.key, entry.value);
            }
          }));
    }
    if (mounted) setState(() => selection = null);
  }

  Color? highlight(String ref) {
    if (selection != null && Bible.overlaps(ref, selection!)) {
      return Theme.of(context).colorScheme.primaryContainer;
    }
    final found =
        user.highlights.entries.where((e) => Bible.overlaps(ref, e.key));
    return found.isEmpty ? null : Color(found.first.value).withAlpha(65);
  }

  Future<void> clearCache() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => SelahDialog(
                title: const Text('Clear saved online chapters?'),
                content: const Text(
                    'NIV and NLT chapters will need internet to open again. Your notes and progress stay on this device.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Clear chapters'))
                ]));
    if (confirmed == true && mounted) {
      await repository.clear();
      if (mounted) await load();
    }
  }

  @override
  void dispose() {
    generation++;
    expiry?.cancel();
    widget.onReady?.call(false);
    WidgetsBinding.instance.removeObserver(this);
    scroll.dispose();
    if (widget.repository == null) repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = content;
    final complete =
        user.history.any((h) => h.reference == reference && h.completed);
    return Scaffold(
        appBar: controlsVisible
            ? AppBar(
                automaticallyImplyLeading: false,
                titleSpacing: 16,
                toolbarHeight: 72,
                title: ReaderToolbar(
                    chapter: label,
                    abbreviation: widget.edition.abbreviation,
                    translation: widget.edition.name,
                    onSearch: widget.onSearch ?? pick,
                    onBooks: pick,
                    onTranslation: widget.onTranslation ?? () {},
                    onTextSize: preferences,
                    onLayout: preferences,
                    hasAudio: false,
                    playing: false,
                    loading: false,
                    audioLabel: '',
                    onAudio: () {}))
            : null,
        body: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.depth != 0 || selection != null) return false;
              if (notification is OverscrollNotification &&
                  notification.dragDetails != null &&
                  notification.metrics.pixels <= 12 &&
                  notification.overscroll < 0) {
                revealAtTopOnly = false;
                showControls(true);
              }
              if (notification is ScrollUpdateNotification &&
                  notification.dragDetails != null) {
                final show = scrollIntent.update(
                    notification.scrollDelta ?? 0, notification.metrics.pixels,
                    visible: controlsVisible);
                if (show == true &&
                    revealAtTopOnly &&
                    notification.metrics.pixels > 12) {
                  return false;
                }
                if (show == true) revealAtTopOnly = false;
                if (show != null) showControls(show);
              }
              return false;
            },
            child: Stack(children: [
              Column(children: [
                Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : error != null
                            ? Center(
                                child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(error!,
                                              textAlign: TextAlign.center),
                                          const SizedBox(height: 16),
                                          FilledButton(
                                              onPressed: load,
                                              child:
                                                  const Text('Retry chapter')),
                                          TextButton(
                                              onPressed: widget.onTranslation ??
                                                  () => Navigator.pop(context),
                                              child: const Text(
                                                  'Back to offline translations')),
                                        ])))
                            : data == null
                                ? const SizedBox.shrink()
                                : Align(
                                    alignment: Alignment.topCenter,
                                    child: ConstrainedBox(
                                        constraints:
                                            const BoxConstraints(maxWidth: 800),
                                        child: PassageSelectionLayer(
                                            key: ValueKey(reference),
                                            scrollController: scroll,
                                            references: [
                                              for (final v in data.verses)
                                                '$reference.${v.number}'
                                            ],
                                            anchors: anchors,
                                            onChanged: (value) => setState(
                                                () => selection = value),
                                            onFinished: actions,
                                            child: ListView(
                                                controller: scroll,
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                        20, 16, 20, 28),
                                                children: [
                                                  Text(label,
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: const TextStyle(
                                                          fontFamily:
                                                              'SourceSerif4',
                                                          fontSize: 30,
                                                          fontWeight:
                                                              FontWeight.bold)),
                                                  const SizedBox(height: 10),
                                                  Text(
                                                      data.cacheFailed
                                                          ? 'Read online · Could not save this chapter'
                                                          : data.refreshFailed
                                                              ? 'Could not refresh · Showing saved chapter'
                                                              : data.cached
                                                                  ? 'Saved chapter · Refresh required within ${(30 - repository.now().difference(data.fetchedAt).inDays).clamp(1, 30)} days'
                                                                  : 'Read online · Saved for offline access up to 30 days',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall),
                                                  const SizedBox(height: 12),
                                                  // Attribution is visible with every chapter, including cached copies.
                                                  Text(data.copyright,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall),
                                                  TextButton(
                                                      onPressed: () => launchUrl(
                                                          Uri.parse(
                                                              'https://api.bible'),
                                                          mode: LaunchMode
                                                              .externalApplication),
                                                      child: const Text(
                                                          'Provided by API.Bible')),
                                                  for (final verse
                                                      in data.verses) ...[
                                                    for (final heading in verse
                                                            .readingFormat
                                                            ?.headings ??
                                                        <String>[])
                                                      Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical: 16),
                                                          child: Text(heading,
                                                              style: TextStyle(
                                                                  fontFamily:
                                                                      'SourceSerif4',
                                                                  fontSize:
                                                                      fontSize,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold))),
                                                    Padding(
                                                        key: anchors.putIfAbsent(
                                                            '$reference.${verse.number}',
                                                            GlobalKey.new),
                                                        padding:
                                                            const EdgeInsets.only(
                                                                bottom: 8),
                                                        child: InkWell(
                                                            key: ValueKey(
                                                                'licensed-verse-$reference.${verse.number}'),
                                                            onTap: writing
                                                                ? null
                                                                : () => actions(
                                                                    '$reference.${verse.number}'),
                                                            child: Container(
                                                                color: highlight(
                                                                    '$reference.${verse.number}'),
                                                                padding: const EdgeInsets
                                                                    .symmetric(
                                                                    vertical:
                                                                        6),
                                                                child:
                                                                    Text.rich(
                                                                        TextSpan(
                                                                            children: [
                                                                              TextSpan(text: '${verse.number}  ', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
                                                                              TextSpan(text: verse.text),
                                                                              if (user.notes.keys.any((r) => Bible.overlaps(r, '$reference.${verse.number}')))
                                                                                const WidgetSpan(child: Icon(Icons.sticky_note_2_outlined, size: 17)),
                                                                              if (user.bookmarks.any((r) => Bible.overlaps(r, '$reference.${verse.number}')))
                                                                                const WidgetSpan(child: Icon(Icons.bookmark, size: 16)),
                                                                            ]),
                                                                        style: TextStyle(
                                                                            fontFamily:
                                                                                'SourceSerif4',
                                                                            fontSize:
                                                                                fontSize,
                                                                            height:
                                                                                1.7))))),
                                                  ],
                                                  ChapterCompletionCard(
                                                      completed: complete,
                                                      saving: writing,
                                                      chapter: label,
                                                      onToggle: () => mutate(
                                                          () => widget.database
                                                              .setCompleted(
                                                                  reference,
                                                                  !complete))),
                                                  const SizedBox(height: 16),
                                                  const Text(
                                                      'Text reading only. Recorded audio is unavailable for these editions; TTS awaits publisher permission.',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                          fontSize: 12)),
                                                ]))))),
                if (MediaQuery.sizeOf(context).width < 840)
                  ColoredBox(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: Center(
                          child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: Padding(
                                  padding: controlsVisible
                                      ? const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8)
                                      : const EdgeInsets.all(8),
                                  child: ChapterNavigation(
                                      label: label,
                                      controlsVisible: controlsVisible,
                                      onPrevious:
                                          canPrevious ? () => move(-1) : null,
                                      onNext: canNext ? () => move(1) : null,
                                      onPick:
                                          loading || writing ? null : pick))))),
              ]),
              if (MediaQuery.sizeOf(context).width >= 840) ...[
                Positioned(
                    left: 16,
                    bottom: 16,
                    child: Material(
                        color:
                            Theme.of(context).colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(18),
                        child: ChapterNavigationArrow(
                            previous: true,
                            onPressed: canPrevious ? () => move(-1) : null))),
                Positioned(
                    right: 16,
                    bottom: 16,
                    child: Material(
                        color:
                            Theme.of(context).colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(18),
                        child: ChapterNavigationArrow(
                            previous: false,
                            onPressed: canNext ? () => move(1) : null))),
              ],
            ])));
  }

  bool get canPrevious => !loading && !writing && (book > 0 || chapter > 0);
  bool get canNext =>
      !loading &&
      !writing &&
      (book < template.books.length - 1 ||
          chapter < template.books[book].chapters.length - 1);
}
