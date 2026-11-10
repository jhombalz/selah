import 'features/common/selah_dialog.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'
    show LicenseRegistry, LicenseEntryWithLineBreaks;
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'data/bible.dart';
import 'data/user_database.dart';
import 'data/bible_search.dart';
import 'features/search/search_page.dart';
import 'features/reader/passage_picker.dart';
import 'features/reader/reader_scroll_intent.dart';
import 'features/reader/chapter_completion_card.dart';
import 'features/branding/selah_brand.dart';
import 'data/translations.dart';
import 'features/translations/translations_page.dart';
import 'data/scripture_range.dart';
import 'features/reader/passage_selection_layer.dart';
import 'data/user_backup.dart';
import 'features/backup/backup_page.dart';
import 'features/audio/chapter_audio.dart';
import 'features/audio/audio_play_button.dart';
import 'features/home/daily_verse_card.dart';
import 'data/daily_verse.dart';
import 'data/growth_entry.dart';
import 'features/growth/growth_page.dart';
import 'features/assessment/assessment_page.dart';
import 'features/study/study_notes_sheet.dart';
import 'features/assessment/assessment_controller.dart';
import 'features/growth/growth_share.dart';
import 'features/focus/focus_controller.dart';
import 'features/focus/focus_page.dart';

void main() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Source Serif 4'],
        await rootBundle.loadString('assets/fonts/source-serif-4/OFL.txt'));
  });
  runApp(const SelahApp());
}

class SelahApp extends StatefulWidget {
  final Bible? initialBible;
  final UserDatabase? database;
  final UserData? initialData;
  final ChapterAudioController? audioController;
  const SelahApp(
      {super.key,
      this.initialBible,
      this.database,
      this.initialData,
      this.audioController});

  @override
  State<SelahApp> createState() => _SelahAppState();
}

class _SelahAppState extends State<SelahApp> {
  bool dark = false;
  bool readerControlsVisible = true;
  final readerScrollIntent = ReaderScrollIntent();
  bool readerUserScrolling = false;
  bool readerRevealAtTopOnly = false;
  late final AssessmentController assessments;
  bool assessmentPageOpen = false;
  Route<void>? assessmentRoute;
  bool savingCompletion = false;
  double fontSize = 21;
  int page = 0;
  final saved = <String>{};
  final highlights = <String, Color>{};
  final notes = <String, String>{};
  Bible? bible;
  Bible? bundledBible;
  final noteTranslations = <String, String>{};
  final verseAnchors = <String, GlobalKey>{};
  String? selectedPassage;
  late final chapterAudio = widget.audioController ?? ChapterAudioController();
  bool followAudio = true;
  bool audioFollowSuspended = false;
  bool audioScrollAnimating = false;
  int audioScrollGeneration = 0;
  String? audioFollowScope;
  ChapterAudioStatus lastAudioStatus = ChapterAudioStatus.idle;
  DateTime? lastAudioPositionSave;
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  String? lastAudioError;
  final focus = FocusController();
  late final focusRoutes = FocusRouteObserver(scheduleFocusSync);
  bool focusSyncScheduled = false;
  bool focusAvailable = false, focusEnabled = false;
  String? pendingFocusAction;
  GrowthEntry? activeGrowthSession;

  void focusChanged() {
    if (!mounted) return;
    if (focusAvailable != focus.available ||
        focusEnabled != focus.status.enabled) {
      setState(() {
        focusAvailable = focus.available;
        focusEnabled = focus.status.enabled;
      });
    }
  }

  void scheduleFocusSync() {
    if (focusSyncScheduled || !mounted) return;
    focusSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusSyncScheduled = false;
      if (!mounted) return;
      final action = pendingFocusAction;
      if (action != null && bible != null) {
        pendingFocusAction = null;
        if (action != 'assessment') {
          navigatorKey.currentState?.popUntil((route) => route.isFirst);
        }
        if (action == 'read') {
          openChapter(bookIndex, chapterIndex, offset: resumeOffset);
        } else if (action == 'settings') {
          openFocusPage();
        } else if (action == 'journey') {
          openGrowthPage();
        } else if (action == 'assessment') {
          unawaited(openAssessments(resume: true));
        }
      }
      unawaited(focus.readingVisible(page == 1 &&
          bible != null &&
          !(navigatorKey.currentState?.canPop() ?? false)));
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void openFocusPage() {
    Navigator.of(navigatorKey.currentContext!).push<void>(MaterialPageRoute(
        builder: (_) => FocusPage(
            controller: focus,
            onRead: () {
              navigatorKey.currentState?.popUntil((route) => route.isFirst);
              openChapter(bookIndex, chapterIndex, offset: resumeOffset);
            })));
  }

  Future<void> openAssessments({bool resume = false}) async {
    if (assessmentPageOpen) {
      navigatorKey.currentState
          ?.popUntil((route) => route == assessmentRoute || route.isFirst);
      assessments.resume();
      return;
    }
    assessmentPageOpen = true;
    if (resume) await assessments.refresh();
    if (!mounted) return;
    try {
      final route = MaterialPageRoute<void>(
          builder: (_) => AssessmentPage(
              database: database,
              controller: assessments,
              initialAttemptId: resume
                  ? assessments.active?.id ?? assessments.latestId
                  : null));
      assessmentRoute = route;
      await navigatorKey.currentState!.push<void>(route);
    } finally {
      assessmentPageOpen = false;
      assessmentRoute = null;
    }
  }

  void readGrowthPassage(GrowthEntry entry) {
    final parts = entry.reference!.split('.');
    final book = bible!.books.indexWhere((book) => book.id == parts[0]);
    final chapter = int.parse(parts[1]) - 1;
    final firstVerse = bible!.books[book].chapters[chapter].firstWhere(
        (verse) => Bible.overlaps(
            '${parts[0]}.${parts[1]}.${verse.number}', entry.reference!));
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
    activeGrowthSession = entry;
    openChapter(book, chapter,
        targetVerse: '${parts[0]}.${parts[1]}.${firstVerse.number}');
  }

  void openGrowthPage() {
    if (bible == null) return;
    final first = bible!.books[bookIndex].chapters[chapterIndex].first;
    final last = bible!.books[bookIndex].chapters[chapterIndex].last;
    final reference =
        '${bible!.books[bookIndex].id}.${chapterIndex + 1}.${first.number.split('-').first}-${last.number.split('-').last}';
    Navigator.of(navigatorKey.currentContext!).push<void>(MaterialPageRoute(
        builder: (_) => GrowthPage(
            database: database,
            bible: bible!,
            currentReference: reference,
            onRead: readGrowthPassage)));
  }

  Future<void> continueGrowthSession() async {
    final active = activeGrowthSession;
    if (active == null || bible == null) return;
    late GrowthEntry entry;
    try {
      final matches = (await database.growthEntries())
          .where((entry) => entry.id == active.id);
      if (matches.isEmpty) {
        if (mounted) setState(() => activeGrowthSession = null);
        return;
      }
      entry = matches.first;
      entry.step = 2;
      await database.saveGrowth(entry);
      activeGrowthSession = entry;
    } catch (_) {
      messengerKey.currentState?.showSnackBar(const SnackBar(
          content: Text('Could not save your session. Please try again.')));
      return;
    }
    if (!mounted) return;
    await Navigator.of(navigatorKey.currentContext!).push<void>(
        MaterialPageRoute(
            builder: (_) => GrowthEditor(
                database: database,
                bible: bible!,
                entry: entry,
                onRead: readGrowthPassage)));
    if (mounted && entry.completed) setState(() => activeGrowthSession = null);
  }

  void audioChanged() {
    if (!mounted) return;
    if (audioFollowScope != chapterAudio.scope) {
      audioFollowScope = chapterAudio.scope;
      audioFollowSuspended = false;
      lastAudioPositionSave = null;
    }
    if (lastAudioStatus != chapterAudio.status ||
        lastAudioError != chapterAudio.error) {
      setState(() {});
    }
    lastAudioStatus = chapterAudio.status;
    if (!chapterAudio.playing) {
      if (audioScrollAnimating && readerScroll.hasClients) {
        audioScrollGeneration++;
        readerScroll.jumpTo(readerScroll.offset);
        audioScrollAnimating = false;
        saveAudioPosition();
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => scrollWithAudio());
      WidgetsBinding.instance.ensureVisualUpdate();
    }
    if (chapterAudio.error != null && chapterAudio.error != lastAudioError) {
      messengerKey.currentState
          ?.showSnackBar(SnackBar(content: Text(chapterAudio.error!)));
    }
    lastAudioError = chapterAudio.error;
  }

  void continueChapterAudio(String scope) {
    if (!mounted ||
        bible == null ||
        scope !=
            '${bible!.id}:${bible!.books[bookIndex].id}.${chapterIndex + 1}') {
      return;
    }
    var book = bookIndex;
    var chapter = chapterIndex + 1;
    if (chapter >= bible!.books[book].chapters.length) {
      book++;
      chapter = 0;
    }
    // Stop at the end of Scripture; never wrap back to Genesis.
    if (book >= bible!.books.length) return;
    openChapter(book, chapter);
    unawaited(
        chapterAudio.toggle(bible!.id, bible!.books[book].id, chapter + 1));
  }

  void saveAudioPosition() {
    if (!mounted || page != 1 || bible == null || !readerScroll.hasClients) {
      return;
    }
    resumeOffset = readerScroll.offset;
    final values = {
      'lastChapter': chapterReference,
      'scrollOffset': '$resumeOffset'
    };
    save(() => database.setPreferences(values));
    lastAudioPositionSave = DateTime.now();
  }

  void scrollWithAudio() {
    if (!mounted ||
        page != 1 ||
        !followAudio ||
        audioFollowSuspended ||
        !chapterAudio.playing ||
        selectedPassage != null ||
        bible == null ||
        (navigatorKey.currentState?.canPop() ?? false) ||
        chapterAudio.scope != '${bible!.id}:$chapterReference' ||
        !readerScroll.hasClients) {
      return;
    }
    final progress = chapterAudio.progress;
    if (progress == null) return;
    final verses = bible!.books[bookIndex].chapters[chapterIndex];
    final prefix = chapterReference;
    final first = verseAnchors['$prefix.${verses.first.number}']
        ?.currentContext
        ?.findRenderObject();
    final last = verseAnchors['$prefix.${verses.last.number}']
        ?.currentContext
        ?.findRenderObject();
    final viewport =
        readerScroll.position.context.notificationContext?.findRenderObject();
    if (first is! RenderBox ||
        last is! RenderBox ||
        viewport is! RenderBox ||
        !first.hasSize ||
        !last.hasSize ||
        !viewport.hasSize) {
      return;
    }
    final origin = viewport.localToGlobal(Offset.zero).dy;
    final start =
        readerScroll.offset + first.localToGlobal(Offset.zero).dy - origin;
    final end = readerScroll.offset +
        last.localToGlobal(Offset(0, last.size.height)).dy -
        origin;
    final target =
        (start + (end - start) * progress - viewport.size.height * .28)
            .clamp(0.0, readerScroll.position.maxScrollExtent);
    if ((target - readerScroll.offset).abs() < 1) return;
    final generation = ++audioScrollGeneration;
    audioScrollAnimating = true;
    unawaited(readerScroll
        .animateTo(target,
            duration: const Duration(milliseconds: 450), curve: Curves.linear)
        .whenComplete(() {
      if (!mounted || generation != audioScrollGeneration) return;
      audioScrollAnimating = false;
      if (lastAudioPositionSave == null ||
          DateTime.now().difference(lastAudioPositionSave!).inSeconds >= 5) {
        saveAudioPosition();
      }
    }));
  }

  void toggleAudioFollowing({bool? enabled}) {
    enabled ??= !followAudio || audioFollowSuspended;
    setState(() {
      followAudio = enabled!;
      audioFollowSuspended = false;
    });
    if (!enabled && audioScrollAnimating && readerScroll.hasClients) {
      audioScrollGeneration++;
      readerScroll.jumpTo(readerScroll.offset);
      audioScrollAnimating = false;
      saveAudioPosition();
    }
    save(() => database.setPreferences({'audioFollow': '$enabled'}));
    if (enabled) scrollWithAudio();
  }

  Future<void> audioInfo(BuildContext context) async {
    final catalog = await RecordedAudioCatalog.load();
    if (!context.mounted) return;
    showDialog<void>(
        context: context,
        builder: (context) => SelahDialog(
              title: const Text('Recorded Bible audio'),
              content: SingleChildScrollView(
                  child: SelectableText(
                      'Streaming requires an internet connection. Recorded narration is available for WEB and BSB.\n\n${[
                catalog,
                ...catalog.alternatives.values
              ].map((edition) => '${edition.translation.toUpperCase()} · ${edition.narrator}\n${edition.editionNote}\n${edition.license}\nSource: ${edition.source}').join('\n\n')}')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'))
              ],
            ));
  }

  String? loadError;
  int bookIndex = 0;
  int chapterIndex = 0;
  final readerScroll = ScrollController();
  late final UserDatabase database;
  late final DailyVerseRepository dailyVerses;
  List<ReadingEntry> history = [];
  String? saveError;
  double resumeOffset = 0;
  Future<void> pendingWrites = Future.value();
  BibleSearch? searchEngine;
  String searchQuery = '';
  String? searchBook;
  bool searchPhrase = false;
  String? focusedVerse;

  List<String> relatedReferences(String verse, Iterable<String> references) =>
      references.where((key) => Bible.overlaps(key, verse)).toList();
  Color? verseHighlight(String verse) {
    if (highlights.containsKey(verse)) return highlights[verse];
    final related = relatedReferences(verse, highlights.keys);
    return related.isEmpty ? null : highlights[related.first];
  }

  String? visibleVerse() {
    if (!readerScroll.hasClients) return focusedVerse;
    final viewport =
        readerScroll.position.context.notificationContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return focusedVerse;
    final top = viewport.localToGlobal(Offset.zero).dy;
    for (final verse in bible!.books[bookIndex].chapters[chapterIndex]) {
      final key =
          '${bible!.books[bookIndex].id}.${chapterIndex + 1}.${verse.number}';
      final box = verseAnchors[key]?.currentContext?.findRenderObject();
      if (box is RenderBox &&
          box.hasSize &&
          box.localToGlobal(Offset(0, box.size.height)).dy > top + 4) {
        return key;
      }
    }
    return focusedVerse;
  }

  Future<void> activateBible(Bible selected, {bool persist = true}) async {
    await chapterAudio.stop();
    final bookId = bible!.books[bookIndex].id;
    final target = page == 1 ? visibleVerse() : null;
    await pendingWrites;
    if (persist) {
      await database
          .setPreferences({'translation': selected.id, 'scrollOffset': '0'});
    }
    if (!mounted) return;
    setState(() {
      bible = selected;
      selectedPassage = null;
      bookIndex = selected.books.indexWhere((book) => book.id == bookId);
      if (bookIndex < 0) bookIndex = 0;
      chapterIndex =
          chapterIndex.clamp(0, selected.books[bookIndex].chapters.length - 1);
      final chapter = selected.books[bookIndex].chapters[chapterIndex];
      final verse = target == null
          ? chapter.first
          : chapter.firstWhere(
              (verse) => Bible.overlaps(target,
                  '${selected.books[bookIndex].id}.${chapterIndex + 1}.${verse.number}'),
              orElse: () => chapter.first);
      focusedVerse = target == null
          ? null
          : '${selected.books[bookIndex].id}.${chapterIndex + 1}.${verse.number}';
      verseAnchors.clear();
      searchEngine = null;
      resumeOffset = 0;
      readerControlsVisible = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !readerScroll.hasClients) return;
      final anchor = verseAnchors[focusedVerse]?.currentContext;
      if (anchor != null) {
        Scrollable.ensureVisible(anchor, alignment: .12);
      } else {
        readerScroll.jumpTo(0);
      }
    });
  }

  Future<void> manageTranslations(BuildContext context) {
    unawaited(chapterAudio.stop());
    return Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => TranslationsPage(
              database: database,
              bundled: bundledBible!,
              activeId: bible!.id,
              onSelect: (selected) => activateBible(selected),
              onRemove: (id) async {
                await pendingWrites;
                await database.removeTranslation(id);
                if (bible!.id == id) {
                  await activateBible(bundledBible!, persist: false);
                }
              },
            )));
  }

  String get chapterReference =>
      '${bible!.books[bookIndex].id}.${chapterIndex + 1}';

  void applyData(UserData data) {
    saved.clear();
    notes.clear();
    noteTranslations.clear();
    highlights.clear();
    bookIndex = 0;
    chapterIndex = 0;
    saved.addAll(data.bookmarks);
    notes.addAll(data.notes);
    noteTranslations.addAll(data.noteTranslations);
    highlights.addAll(
        data.highlights.map((key, value) => MapEntry(key, Color(value))));
    history = data.history;
    dark = data.preferences['dark'] == 'true';
    followAudio = data.preferences['audioFollow'] != 'false';
    fontSize = (double.tryParse(data.preferences['fontSize'] ?? '') ?? 21)
        .clamp(16, 32);
    resumeOffset =
        (double.tryParse(data.preferences['scrollOffset'] ?? '') ?? 0);
    if (!resumeOffset.isFinite || resumeOffset < 0) resumeOffset = 0;
    final location = data.preferences['lastChapter']?.split('.');
    if (location != null && location.length == 2) {
      final index = bible!.books.indexWhere((b) => b.id == location[0]);
      final chapter = int.tryParse(location[1]);
      if (index >= 0 &&
          chapter != null &&
          chapter >= 1 &&
          chapter <= bible!.books[index].chapters.length) {
        bookIndex = index;
        chapterIndex = chapter - 1;
      }
    }
  }

  Future<void> manageBackups(BuildContext context) =>
      Navigator.of(context).push<void>(MaterialPageRoute(
          builder: (_) => BackupPage(
                canon: bundledBible!,
                capture: () async {
                  await pendingWrites;
                  return BackupService(database, bundledBible!).capture();
                },
                restore: (backup, mode) async {
                  await pendingWrites;
                  final result = await BackupService(database, bundledBible!)
                      .restore(backup, mode);
                  Bible restoredBible = bundledBible!;
                  final id = result.data.preferences['translation'] ?? 'cebocb';
                  if (id != 'cebocb') {
                    try {
                      restoredBible = await loadInstalledBible(database, id) ??
                          bundledBible!;
                    } catch (_) {
                      /* The restored user data is intact; keep reading available. */
                    }
                  }
                  if (mounted) {
                    setState(() {
                      bible = restoredBible;
                      applyData(result.data);
                      searchEngine = null;
                      focusedVerse = null;
                      selectedPassage = null;
                      verseAnchors.clear();
                      readerControlsVisible = true;
                    });
                  }
                  return result;
                },
              )));

  String translationNameFor(String id) {
    for (final spec in translationCatalog) {
      if (spec.id == id) return spec.abbreviation;
    }
    return id.toUpperCase();
  }

  Future<void> save(Future<void> Function() action, [VoidCallback? success]) {
    final write = pendingWrites.then((_) => action()).then((_) {
      if (mounted) {
        setState(() {
          saveError = null;
          success?.call();
        });
      }
    }).catchError((Object error) {
      if (mounted) {
        setState(() => saveError =
            'Your latest change could not be saved. Please try it again.');
      }
    });
    pendingWrites = write;
    return write;
  }

  void updatePreference(String key, String value, VoidCallback success) {
    save(() => database.setPreferences({key: value}), success);
  }

  void selectPage(int value) {
    if (value != 1) unawaited(chapterAudio.stop());
    if (value == 1) {
      openChapter(bookIndex, chapterIndex, offset: resumeOffset);
    } else {
      setState(() {
        page = value;
        selectedPassage = null;
        readerControlsVisible = true;
      });
    }
  }

  void openChapter(int book, int chapter,
      {double offset = 0, String? targetVerse}) {
    final keepHidden =
        page == 1 && !readerControlsVisible && targetVerse == null;
    readerRevealAtTopOnly = keepHidden;
    readerScrollIntent.reset();
    readerUserScrolling = false;
    if (page != 1 || book != bookIndex || chapter != chapterIndex) {
      unawaited(chapterAudio.stop());
    }
    setState(() {
      page = 1;
      selectedPassage = null;
      readerControlsVisible = !keepHidden;
      bookIndex = book;
      chapterIndex = chapter;
      resumeOffset = offset;
      focusedVerse = targetVerse;
      verseAnchors.clear();
    });
    final reference = chapterReference;
    save(() async {
      await database.visit(reference, offset: offset);
      final data = await database.load();
      if (mounted) setState(() => history = data.history);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && readerScroll.hasClients) {
        final targetContext = verseAnchors[targetVerse]?.currentContext;
        if (targetVerse != null && targetContext != null) {
          Scrollable.ensureVisible(targetContext, alignment: 0.12);
        } else {
          readerScroll
              .jumpTo(offset.clamp(0, readerScroll.position.maxScrollExtent));
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    focus.addListener(focusChanged);
    focus.onAction = (action) {
      pendingFocusAction = action;
      scheduleFocusSync();
    };
    unawaited(focus.start());
    chapterAudio.addListener(audioChanged);
    chapterAudio.onCompleted = continueChapterAudio;
    database = widget.database ?? UserDatabase.local();
    assessments = AssessmentController(database)..start();
    dailyVerses = DailyVerseRepository(database: database);
    if (widget.initialBible != null && widget.initialData != null) {
      bible = widget.initialBible;
      bundledBible = widget.initialBible;
      applyData(widget.initialData!);
    } else {
      loadBible();
    }
  }

  Future<void> loadBible() async {
    setState(() => loadError = null);
    try {
      final bundled = widget.initialBible ?? await Bible.load();
      final userData = await database.load();
      Bible loaded = bundled;
      final selectedId = userData.preferences['translation'] ?? 'cebocb';
      String? warning;
      if (selectedId != 'cebocb') {
        try {
          loaded = await loadInstalledBible(database, selectedId) ?? bundled;
        } catch (_) {
          warning =
              'The selected translation could not be opened. The bundled Cebuano Bible is available; you can re-download the other edition in Settings.';
        }
      }
      if (mounted) {
        setState(() {
          bible = loaded;
          bundledBible = bundled;
          saveError = warning;
          applyData(userData);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => loadError =
            'SELAH or local storage could not be opened. Please retry. Your stored data has not been reset.');
      }
    }
  }

  @override
  void dispose() {
    assessments.dispose();
    focus.removeListener(focusChanged);
    focus.dispose();
    dailyVerses.dispose();
    chapterAudio.removeListener(audioChanged);
    chapterAudio.onCompleted = null;
    chapterAudio.dispose();
    readerScroll.dispose();
    if (widget.database == null) {
      pendingWrites.whenComplete(database.close);
    }
    super.dispose();
  }

  void moveChapter(int direction) {
    int book = bookIndex;
    int chapter = chapterIndex + direction;
    if (chapter < 0) {
      book--;
      chapter = bible!.books[book].chapters.length - 1;
    } else if (chapter >= bible!.books[book].chapters.length) {
      book++;
      chapter = 0;
    }
    openChapter(book, chapter);
  }

  Future<void> showCopyright(BuildContext context) async {
    final notice = bible!.id == 'cebocb'
        ? await rootBundle.loadString('assets/bible/LICENSE.txt')
        : bible!.licenseText;
    if (!context.mounted) return;
    showDialog<void>(
        context: context,
        builder: (context) => SelahDialog(
              title: const Text('Bible copyright & license'),
              content: SizedBox(
                  width: 620,
                  child: SingleChildScrollView(child: SelectableText(notice))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'))
              ],
            ));
  }

  ThemeData theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff24634d),
      brightness: brightness,
    ).copyWith(
      primary: Color(dark ? 0xffa0cdb7 : 0xff24634d),
      onPrimary: Color(dark ? 0xff18201c : 0xfff7f3ea),
      primaryContainer: Color(dark ? 0xff304e3f : 0xffdce9df),
      onPrimaryContainer: Color(dark ? 0xffe7e5dc : 0xff244735),
      surface: Color(dark ? 0xff18201c : 0xfff7f3ea),
      onSurface: Color(dark ? 0xffe7e5dc : 0xff292d29),
      onSurfaceVariant: Color(dark ? 0xffadb6ac : 0xff62685f),
      surfaceContainerLowest: Color(dark ? 0xff141b17 : 0xfffcf9f3),
      surfaceContainerLow: Color(dark ? 0xff202c25 : 0xffeff1e9),
      surfaceContainer: Color(dark ? 0xff25332c : 0xffe8ede4),
      surfaceContainerHigh: Color(dark ? 0xff2d3b33 : 0xffe0e6dc),
      surfaceContainerHighest: Color(dark ? 0xff35443b : 0xffd8dfd4),
      secondary: Color(dark ? 0xffc7af7d : 0xff766039),
      onSecondary: Color(dark ? 0xff241e12 : 0xffffffff),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      dialogTheme: DialogThemeData(
          backgroundColor: scheme.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
      bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: scheme.surface,
          showDragHandle: true,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)))),
      appBarTheme: AppBarTheme(
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          surfaceTintColor: Colors.transparent),
    );
  }

  Future<void> annotate(String verse) async {
    final controller = TextEditingController(text: notes[verse]);
    final route = DialogRoute<void>(
      context: navigatorKey.currentContext!,
      builder: (context) => SelahDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(children: [
          Expanded(
              child: Text(
                  notes.containsKey(verse) ? 'Edit your note' : 'Write a note',
                  style: const TextStyle(
                      fontFamily: 'SourceSerif4', fontSize: 28))),
          IconButton(
              tooltip: 'Close note',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded)),
        ]),
        content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(18)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${bible!.reference(verse)} · ${bible!.abbreviation}',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color:
                                        Theme.of(context).colorScheme.primary)),
                            const SizedBox(height: 10),
                            Text(bible!.verse(verse).text,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontFamily: 'SourceSerif4',
                                    fontSize: 17,
                                    height: 1.5)),
                          ])),
                  const SizedBox(height: 22),
                  const Text('Your reflection',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    minLines: 4,
                    maxLines: 8,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                        hintText: 'What speaks to you in this passage?',
                        filled: true,
                        fillColor:
                            Theme.of(context).colorScheme.surfaceContainerLow,
                        contentPadding: const EdgeInsets.all(18),
                        border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                            borderRadius: BorderRadius.circular(18)),
                        enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide.none,
                            borderRadius: BorderRadius.circular(18)),
                        focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary),
                            borderRadius: BorderRadius.circular(18))),
                  ),
                  const SizedBox(height: 12),
                  Text(
                      'Only on this device. Included in your user-data backups.',
                      style: TextStyle(
                          fontSize: 12,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                ]))),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final text = controller.text.trim();
              await save(
                  () => database.setNote(verse, text.isEmpty ? null : text,
                      sourceTranslation: bible!.id), () {
                if (text.isEmpty) {
                  notes.remove(verse);
                  noteTranslations.remove(verse);
                } else {
                  notes[verse] = text;
                  noteTranslations.putIfAbsent(verse, () => bible!.id);
                }
              });
              if (context.mounted && saveError == null) Navigator.pop(context);
            },
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Save note'),
          ),
        ],
      ),
    );
    await Navigator.of(navigatorKey.currentContext!).push(route);
    // The field remains mounted during the closing animation and keyboard resize.
    await route.completed;
    controller.dispose();
  }

  final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) => MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [focusRoutes],
        scaffoldMessengerKey: messengerKey,
        debugShowCheckedModeBanner: false,
        title: 'SELAH',
        theme: theme(Brightness.light),
        darkTheme: theme(Brightness.dark),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        builder: (context, child) => FocusTimerFrame(
            controller: focus,
            child: AssessmentTimerFrame(
                controller: assessments,
                onOpen: () => unawaited(openAssessments(resume: true)),
                child: child ?? const SizedBox.shrink())),
        home: LayoutBuilder(
          builder: (context, constraints) {
            scheduleFocusSync();
            final wide = constraints.maxWidth >= 840;
            final readingFocus = page == 1 && !readerControlsVisible;
            final content = bible == null
                ? Center(
                    child: loadError == null
                        ? const CircularProgressIndicator()
                        : Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(loadError!),
                            TextButton(
                                onPressed: loadBible,
                                child: const Text('Retry')),
                          ]))
                : page == 0
                    ? home(context)
                    : page == 1
                        ? reader(context)
                        : page == 2
                            ? SearchPage(
                                search: searchEngine ??= BibleSearch(bible!),
                                initialQuery: searchQuery,
                                initialBook: searchBook,
                                initialPhrase: searchPhrase,
                                onOptionsChanged: (query, book, phrase) {
                                  searchQuery = query;
                                  searchBook = book;
                                  searchPhrase = phrase;
                                },
                                onOpen: (hit) => openChapter(
                                    hit.bookIndex, hit.chapterIndex,
                                    targetVerse: hit.key),
                              )
                            : page == 3
                                ? library(context)
                                : settings(context);
            return Scaffold(
              appBar: readingFocus
                  ? null
                  : page == 1 && bible != null
                      ? AppBar(
                          automaticallyImplyLeading: false,
                          titleSpacing: 16,
                          toolbarHeight: 72,
                          title: readerToolbar(context),
                        )
                      : AppBar(
                          toolbarHeight: 72,
                          title: const SelahBrand(),
                          actions: [
                            IconButton(
                              tooltip: dark ? 'Light theme' : 'Dark theme',
                              onPressed: () {
                                final value = !dark;
                                updatePreference(
                                    'dark', '$value', () => dark = value);
                              },
                              icon: Icon(
                                dark
                                    ? Icons.light_mode_outlined
                                    : Icons.dark_mode_outlined,
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                        ),
              body: SafeArea(
                  top: readingFocus,
                  bottom: readingFocus,
                  child: Column(children: [
                    if (saveError != null)
                      MaterialBanner(
                        content: Text(saveError!),
                        actions: [
                          TextButton(
                              onPressed: () => setState(() => saveError = null),
                              child: const Text('Dismiss'))
                        ],
                      ),
                    Expanded(
                        child: Row(
                      children: [
                        if (wide && !readingFocus)
                          NavigationRail(
                            selectedIndex: page,
                            onDestinationSelected: selectPage,
                            labelType: NavigationRailLabelType.all,
                            backgroundColor: Colors.transparent,
                            destinations: const [
                              NavigationRailDestination(
                                  icon: Icon(Icons.home_outlined),
                                  label: Text('Home')),
                              NavigationRailDestination(
                                icon: Icon(Icons.auto_stories_outlined),
                                label: Text('Bible'),
                              ),
                              NavigationRailDestination(
                                icon: Icon(Icons.search),
                                label: Text('Search'),
                              ),
                              NavigationRailDestination(
                                icon: Icon(Icons.bookmarks_outlined),
                                label: Text('Saved'),
                              ),
                              NavigationRailDestination(
                                icon: Icon(Icons.tune),
                                label: Text('Settings'),
                              ),
                            ],
                          ),
                        Expanded(
                            key: const ValueKey('page-content'),
                            child: content),
                      ],
                    )),
                  ])),
              bottomNavigationBar: wide || readingFocus
                  ? null
                  : NavigationBar(
                      selectedIndex: page,
                      onDestinationSelected: selectPage,
                      destinations: const [
                        NavigationDestination(
                            icon: Icon(Icons.home_outlined), label: 'Home'),
                        NavigationDestination(
                          icon: Icon(Icons.auto_stories_outlined),
                          label: 'Bible',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.search),
                          label: 'Search',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.bookmarks_outlined),
                          label: 'Saved',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.tune),
                          label: 'Settings',
                        ),
                      ],
                    ),
            );
          },
        ),
      );

  Widget centered(Widget child) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: child,
        ),
      );

  String chapterLabel(String reference) {
    final parts = reference.split('.');
    final books = bible!.books.where((book) => book.id == parts.first);
    return books.isEmpty ? reference : '${books.first.name} ${parts.last}';
  }

  void openReference(String reference) {
    final parts = reference.split('.');
    final book = bible!.books.indexWhere((book) => book.id == parts.first);
    final chapter = int.tryParse(parts.last);
    if (book >= 0 &&
        chapter != null &&
        chapter >= 1 &&
        chapter <= bible!.books[book].chapters.length) {
      openChapter(book, chapter - 1);
    }
  }

  Widget historyTile(BuildContext context, ReadingEntry entry,
          {VoidCallback? close}) =>
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: entry.completed
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14)),
            child: Icon(
                entry.completed ? Icons.check_rounded : Icons.history_rounded,
                size: 21,
                color: entry.completed
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant)),
        title: Text(chapterLabel(entry.reference),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${MaterialLocalizations.of(context).formatMediumDate(entry.visitedAt.toLocal())} · ${entry.completed ? 'Read' : 'Opened'}',
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        trailing: Icon(Icons.chevron_right_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
        onTap: () {
          close?.call();
          openReference(entry.reference);
        },
      );

  Widget journeyStat(BuildContext context,
          {required IconData icon,
          required int count,
          required String label}) =>
      Expanded(
          child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon,
                        size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 10),
                    Text('$count',
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w600)),
                    Text(label,
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ])));

  Widget home(BuildContext context) {
    final completed = history.where((entry) => entry.completed).length;
    return centered(ListView(padding: const EdgeInsets.all(28), children: [
      const SizedBox(height: 16),
      Text('PAUSE. REFLECT. GROW.',
          style: TextStyle(
              letterSpacing: 3,
              fontSize: 11,
              color: Theme.of(context).colorScheme.primary)),
      const SizedBox(height: 20),
      const Text('Pause here.\nGrow in the Word.',
          style:
              TextStyle(fontFamily: 'SourceSerif4', fontSize: 36, height: 1.2)),
      const SizedBox(height: 16),
      const Text('Find a quiet moment with Scripture, one chapter at a time.'),
      const SizedBox(height: 28),
      Card(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        history.isEmpty
                            ? 'YOUR FIRST MOMENT'
                            : 'PICK UP WHERE YOU PAUSED',
                        style: const TextStyle(fontSize: 11, letterSpacing: 2)),
                    const SizedBox(height: 12),
                    Text(chapterLabel(chapterReference),
                        style: const TextStyle(
                            fontFamily: 'SourceSerif4', fontSize: 28)),
                    Text('${bible!.title} · ${bible!.language}'),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                        onPressed: () => openChapter(bookIndex, chapterIndex,
                            offset: resumeOffset),
                        icon: const Icon(Icons.menu_book_outlined),
                        label: const Text('Continue Reading')),
                  ]))),
      const SizedBox(height: 24),
      DailyVerseCard(
          bible: bible!,
          repository: dailyVerses,
          onOpen: (reference) {
            final parts = reference.split('.');
            openChapter(bible!.books.indexWhere((book) => book.id == parts[0]),
                int.parse(parts[1]) - 1,
                targetVerse: reference);
          }),
      const SizedBox(height: 24),
      Card(
          child: ListTile(
              contentPadding: const EdgeInsets.all(20),
              leading: const Icon(Icons.spa_outlined, size: 32),
              title: const Text('My time with God'),
              subtitle: const Text(
                  'Pause. Read. Reflect. Pray. Live.\nGuided moments and your private prayer journal.'),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: openGrowthPage)),
      Card(
          child: ListTile(
              leading: const Icon(Icons.quiz_outlined),
              title: const Text('Bible assessments'),
              subtitle: const Text(
                  'Five levels · Learn, reflect, and grow in understanding'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openAssessments())),
      const SizedBox(height: 24),
      Card(
          margin: EdgeInsets.zero,
          child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your reading journey',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text('A little each day, at your own pace.',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                    const SizedBox(height: 22),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${(completed / 1189 * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                              fontFamily: 'SourceSerif4', fontSize: 36)),
                      const SizedBox(width: 10),
                      const Expanded(
                          child: Padding(
                              padding: EdgeInsets.only(bottom: 7),
                              child: Text('of the Bible read',
                                  style: TextStyle(fontSize: 12)))),
                    ]),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                        value: completed / 1189,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8)),
                    const SizedBox(height: 12),
                    Text('$completed of 1,189 chapters marked as read',
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                    const SizedBox(height: 22),
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          journeyStat(context,
                              icon: Icons.bookmark_border_rounded,
                              count: saved.length,
                              label: 'Bookmarks'),
                          const SizedBox(width: 12),
                          journeyStat(context,
                              icon: Icons.edit_note_rounded,
                              count: notes.length,
                              label: 'Reflections'),
                        ]),
                  ]))),
      const SizedBox(height: 28),
      Text('Recently opened', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      if (history.isEmpty)
        Card(
            margin: EdgeInsets.zero,
            child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.auto_stories_outlined,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 12),
                      const Text('Your next chapter starts here.',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      const Text(
                          'Recently opened chapters will appear here. Mark a chapter as read when you finish.'),
                    ]))),
      if (history.isNotEmpty)
        Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (int index = 0; index < history.take(5).length; index++) ...[
                if (index > 0)
                  Divider(
                      height: 1,
                      indent: 78,
                      endIndent: 18,
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: .5)),
                historyTile(context, history[index]),
              ],
            ])),
      if (history.length > 5)
        TextButton(
            onPressed: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => SelahDialog(
                      title: const Text('Reading history'),
                      content: SizedBox(
                          width: 560,
                          height: 460,
                          child: ListView.builder(
                              itemCount: history.length,
                              itemBuilder: (context, index) => historyTile(
                                  context, history[index],
                                  close: () => Navigator.pop(dialogContext)))),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Close'))
                      ],
                    )),
            child: const Text('View reading history')),
      const SizedBox(height: 24),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.lock_outline_rounded,
            size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
            child: Text(
                'Your reflections stay on this device. No account needed.',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant))),
      ]),
    ]));
  }

  Future<void> pickPassage(BuildContext context) async {
    await chapterAudio.stop();
    if (!context.mounted) return;
    final picker = PassagePicker(
        bible: bible!, currentBook: bookIndex, currentChapter: chapterIndex);
    final selection = MediaQuery.sizeOf(context).width < 840
        ? await Navigator.of(context).push<PassageSelection>(
            MaterialPageRoute(fullscreenDialog: true, builder: (_) => picker))
        : await showDialog<PassageSelection>(
            context: context,
            builder: (context) => SelahDialog(
                  contentPadding: EdgeInsets.zero,
                  content: SizedBox(
                      width: 600,
                      height: MediaQuery.sizeOf(context).height * .8,
                      child: picker),
                ));
    if (selection != null && mounted) {
      openChapter(selection.book, selection.chapter);
    }
  }

  Future<void> adjustText(BuildContext context) async {
    double preview = fontSize;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (context) => StatefulBuilder(builder: (context, updateSheet) {
        void change(double value, {bool persist = true}) {
          updateSheet(() => preview = value.clamp(16, 32));
          setState(() => fontSize = preview);
          if (persist) updatePreference('fontSize', '$preview', () {});
        }

        return SafeArea(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Expanded(
                        child: Text('Reading text size',
                            style: Theme.of(context).textTheme.titleLarge)),
                    IconButton(
                        tooltip: 'Close text size',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close)),
                  ]),
                  const SizedBox(height: 20),
                  Row(children: [
                    IconButton(
                        tooltip: 'Smaller text',
                        onPressed:
                            preview <= 16 ? null : () => change(preview - 1),
                        icon: const Icon(Icons.text_decrease)),
                    Expanded(
                        child: Slider(
                            label: '${preview.round()}',
                            value: preview,
                            min: 16,
                            max: 32,
                            divisions: 16,
                            onChanged: (value) => change(value, persist: false),
                            onChangeEnd: (value) => change(value))),
                    IconButton(
                        tooltip: 'Larger text',
                        onPressed:
                            preview >= 32 ? null : () => change(preview + 1),
                        icon: const Icon(Icons.text_increase)),
                  ]),
                  Text('${preview.round()} pt',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 20),
                  Text('Pause. Reflect. Grow.',
                      style: TextStyle(
                          fontFamily: 'SourceSerif4',
                          fontSize: preview,
                          height: 1.6)),
                  const SizedBox(height: 12),
                ])));
      }),
    );
  }

  Widget readerToolbar(BuildContext context) => Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Container(
            key: const ValueKey('reader-toolbar'),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: .45))),
            child: Row(children: [
              Expanded(
                  child: Tooltip(
                      message: 'Choose a book and chapter',
                      child: TextButton(
                          onPressed: () => pickPassage(context),
                          style: TextButton.styleFrom(
                              minimumSize: const Size(0, 44),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              foregroundColor:
                                  Theme.of(context).colorScheme.onSurface),
                          child: Row(children: [
                            Expanded(
                                child: Text(
                                    '${bible!.books[bookIndex].name} ${chapterIndex + 1}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600))),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_down_rounded,
                                size: 20),
                          ])))),
              IconButton(
                  tooltip: 'Search Bible',
                  onPressed: () => selectPage(2),
                  icon: const Icon(Icons.search_rounded, size: 22)),
              const SizedBox(width: 4),
              Tooltip(
                  message: bible!.title,
                  child: FilledButton.tonal(
                    key: const ValueKey('translation-picker'),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size(56, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16))),
                    onPressed: () => manageTranslations(context),
                    child: Text(bible!.abbreviation,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  )),
              const SizedBox(width: 6),
              Tooltip(
                  message: 'Adjust text size',
                  child: TextButton(
                    key: const ValueKey('text-size'),
                    style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16))),
                    onPressed: () => adjustText(context),
                    child: const Text('AA',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  )),
            ])),
      ));

  Widget reader(BuildContext context) {
    final book = bible!.books[bookIndex];
    final chapter = book.chapters[chapterIndex];
    final completed = history
        .any((entry) => entry.reference == chapterReference && entry.completed);
    return Column(children: [
      if (activeGrowthSession != null)
        Material(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: ListTile(
                dense: true,
                leading: const Icon(Icons.spa_outlined),
                title: const Text('Your quiet moment'),
                trailing: TextButton(
                    onPressed: continueGrowthSession,
                    child: const Text('Continue reflection')))),
      Expanded(
          child: centered(PassageSelectionLayer(
              key: ValueKey('select-${bible!.id}-$chapterReference'),
              scrollController: readerScroll,
              references: [
                for (final verse in chapter)
                  '${book.id}.${chapterIndex + 1}.${verse.number}'
              ],
              anchors: verseAnchors,
              onChanged: (reference) =>
                  setState(() => selectedPassage = reference),
              onFinished: (reference) async {
                if (!mounted || page != 1) return;
                if (readerScroll.hasClients) {
                  resumeOffset = readerScroll.offset;
                  final preferences = {
                    'lastChapter': chapterReference,
                    'scrollOffset': '$resumeOffset'
                  };
                  save(() => database.setPreferences(preferences));
                }
                try {
                  await showVerseActions(context, reference);
                } finally {
                  if (mounted) setState(() => selectedPassage = null);
                }
              },
              child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (selectedPassage != null) return false;
                    if (notification.depth != 0) return false;
                    if (notification is OverscrollNotification &&
                        notification.overscroll < 0 &&
                        notification.metrics.pixels <= 12 &&
                        (notification.dragDetails != null ||
                            readerUserScrolling)) {
                      readerRevealAtTopOnly = false;
                      if (!readerControlsVisible) {
                        setState(() => readerControlsVisible = true);
                      }
                    }
                    if (notification is UserScrollNotification) {
                      readerUserScrolling =
                          notification.direction != ScrollDirection.idle;
                    }
                    if (notification is UserScrollNotification &&
                        notification.direction == ScrollDirection.idle) {
                      readerScrollIntent.reset();
                    }
                    if (notification is UserScrollNotification &&
                        notification.direction != ScrollDirection.idle &&
                        chapterAudio.playing &&
                        !audioFollowSuspended) {
                      setState(() => audioFollowSuspended = true);
                      audioScrollGeneration++;
                      audioScrollAnimating = false;
                    }
                    if (notification is ScrollUpdateNotification &&
                        (notification.dragDetails != null ||
                            readerUserScrolling)) {
                      final show = readerScrollIntent.update(
                          notification.scrollDelta ?? 0,
                          notification.metrics.pixels,
                          visible: readerControlsVisible);
                      if (show == true &&
                          readerRevealAtTopOnly &&
                          notification.metrics.pixels > 12) {
                        return false;
                      }
                      if (show == true) readerRevealAtTopOnly = false;
                      if (show != null && readerControlsVisible != show) {
                        setState(() => readerControlsVisible = show);
                      }
                    }
                    return false;
                  },
                  child: NotificationListener<ScrollEndNotification>(
                    onNotification: (notification) {
                      if (selectedPassage != null || audioScrollAnimating) {
                        return false;
                      }
                      resumeOffset = notification.metrics.pixels
                          .clamp(0, notification.metrics.maxScrollExtent);
                      final values = {
                        'lastChapter': chapterReference,
                        'scrollOffset': '$resumeOffset'
                      };
                      save(() => database.setPreferences(values));
                      return false;
                    },
                    child: SingleChildScrollView(
                      controller: readerScroll,
                      padding: const EdgeInsets.fromLTRB(18, 30, 18, 24),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('${book.name} ${chapterIndex + 1}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontFamily: 'SourceSerif4',
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 36),
                            for (final verse in chapter)
                              verseTile(
                                  '${book.id}.${chapterIndex + 1}.${verse.number}'),
                            const SizedBox(height: 24),
                            ChapterCompletionCard(
                                completed: completed,
                                saving: savingCompletion,
                                chapter: '${book.name} ${chapterIndex + 1}',
                                onToggle: () async {
                                  final reference = chapterReference;
                                  setState(() => savingCompletion = true);
                                  await save(() async {
                                    await database.setCompleted(
                                        reference, !completed);
                                    final data = await database.load();
                                    if (mounted) {
                                      setState(() => history = data.history);
                                    }
                                  });
                                  if (mounted) {
                                    setState(() => savingCompletion = false);
                                  }
                                }),
                            const SizedBox(height: 12),
                            TextButton(
                                onPressed: () => showCopyright(context),
                                child: const Text('Bible copyright & license')),
                          ]),
                    ),
                  ))))),
      SizedBox(width: double.infinity, child: readerDock(context, book)),
    ]);
  }

  Widget readerDock(BuildContext context, BibleBook book) {
    final hasAudio = ChapterAudioController.available(bible!.id);
    final navigation = Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      elevation: readerControlsVisible ? 3 : 0,
      borderRadius: BorderRadius.circular(40),
      clipBehavior: Clip.antiAlias,
      child: Row(children: [
        chapterArrow(context,
            previous: true, enabled: bookIndex > 0 || chapterIndex > 0),
        Expanded(
            child: TextButton(
          key: const ValueKey('passage-picker'),
          style: TextButton.styleFrom(
              minimumSize: const Size(0, 56),
              foregroundColor: Theme.of(context).colorScheme.onSurface),
          onPressed: () => pickPassage(context),
          child: Text(
              selectedPassage == null
                  ? '${book.name} ${chapterIndex + 1}'
                  : bible!.reference(selectedPassage!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        )),
        chapterArrow(context,
            previous: false,
            enabled: bookIndex < bible!.books.length - 1 ||
                chapterIndex < book.chapters.length - 1),
      ]),
    );
    return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: readerControlsVisible
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                : const EdgeInsets.all(8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (hasAudio &&
                  (chapterAudio.playing ||
                      chapterAudio.status == ChapterAudioStatus.paused))
                Align(
                    alignment: Alignment.centerRight,
                    child: Tooltip(
                        message:
                            'Approximate chapter progress, without verse timing. Scrolling manually pauses following.',
                        child: TextButton.icon(
                            onPressed: toggleAudioFollowing,
                            icon: Icon(
                                followAudio && !audioFollowSuspended
                                    ? Icons.sync_rounded
                                    : Icons.vertical_align_center_rounded,
                                size: 18),
                            label: Text(audioFollowSuspended
                                ? 'Resume auto-scroll'
                                : followAudio
                                    ? 'Auto-scroll on'
                                    : 'Auto-scroll off')))),
              Row(children: [
                if (hasAudio) ...[
                  AudioPlayButton(
                      playing: chapterAudio.playing,
                      loading: chapterAudio.loading,
                      label: chapterAudio.playing
                          ? 'Pause ${bible!.abbreviation} audio'
                          : chapterAudio.status == ChapterAudioStatus.paused
                              ? 'Resume ${bible!.abbreviation} audio · Internet required'
                              : 'Play ${bible!.abbreviation} audio · Internet required',
                      onPressed: () => chapterAudio.toggle(
                          bible!.id, book.id, chapterIndex + 1)),
                  const SizedBox(width: 8),
                ],
                Expanded(child: navigation),
              ])
            ]),
          ),
        )));
  }

  Widget chapterArrow(BuildContext context,
          {required bool previous, required bool enabled}) =>
      IconButton(
          tooltip: previous ? 'Previous chapter' : 'Next chapter',
          style: IconButton.styleFrom(
              minimumSize: const Size(52, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16))),
          onPressed: enabled ? () => moveChapter(previous ? -1 : 1) : null,
          icon: Icon(previous ? Icons.chevron_left : Icons.chevron_right,
              size: 30));

  Future<void> colorPassage(String reference, int? color) {
    final changed = recolorPassage(
        highlights.map((key, value) => MapEntry(key, value.toARGB32())),
        reference,
        color);
    final prior = relatedReferences(reference, highlights.keys);
    return save(
        () => database.transaction(() async {
              for (final key in prior) {
                await database.setHighlight(key, null);
              }
              for (final entry in changed.entries) {
                if (highlights[entry.key]?.toARGB32() != entry.value ||
                    prior.contains(entry.key)) {
                  await database.setHighlight(entry.key, entry.value);
                }
              }
            }), () {
      highlights
        ..clear()
        ..addAll(changed.map((key, value) => MapEntry(key, Color(value))));
    });
  }

  Future<void> showVerseActions(BuildContext context, String verse) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
        builder: (sheetContext) => SafeArea(
            child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                children: [
              Text(
                '${bible!.reference(verse)} · ${bible!.abbreviation}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_outline),
                title: Text(
                  (verse.contains('-')
                          ? saved.contains(verse)
                          : relatedReferences(verse, saved).isNotEmpty)
                      ? 'Remove bookmark'
                      : verse.contains('-')
                          ? 'Bookmark selection'
                          : 'Bookmark verse',
                ),
                onTap: () async {
                  final related = verse.contains('-')
                      ? [if (saved.contains(verse)) verse]
                      : relatedReferences(verse, saved);
                  final add = related.isEmpty;
                  await save(
                      () => database.transaction(() async {
                            if (add) {
                              await database.setBookmark(verse, true);
                            } else {
                              for (final reference in related) {
                                await database.setBookmark(reference, false);
                              }
                            }
                          }), () {
                    if (add) {
                      saved.add(verse);
                    } else {
                      saved.removeAll(related);
                    }
                  });
                  if (sheetContext.mounted && saveError == null) {
                    Navigator.pop(sheetContext);
                  }
                },
              ),
              for (final reference in relatedReferences(verse, notes.keys))
                ListTile(
                  leading: const Icon(Icons.edit_note),
                  title:
                      Text('Edit reflection · ${bible!.reference(reference)}'),
                  subtitle: Text(
                      'Created in ${translationNameFor(noteTranslations[reference] ?? 'cebocb')}'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    annotate(reference);
                  },
                ),
              ListTile(
                  leading: const Icon(Icons.ios_share),
                  title: const Text('Share passage'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    final selection = GrowthEntry.create(
                        kind: 'session',
                        title: 'Scripture',
                        translation: bible!.id,
                        reference: verse);
                    final related = relatedReferences(verse, notes.keys);
                    selection.reflection = related
                        .map((reference) => notes[reference]!)
                        .join('\n\n');
                    previewGrowthShare(context, bible!, selection);
                  }),
              ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: const Text('Study notes'),
                  subtitle:
                      const Text('Tyndale · English · saved after opening'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    showStudyNotes(context, bible!, database, verse);
                  }),
              if (!notes.containsKey(verse))
                ListTile(
                  leading: const Icon(Icons.edit_note),
                  title: const Text('Write a reflection'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    annotate(verse);
                  },
                ),
              const Text('Highlight'),
              Wrap(
                spacing: 12,
                children: [
                  for (final color in [
                    Colors.amber,
                    Colors.green,
                    Colors.blue,
                    Colors.pink,
                  ])
                    IconButton(
                      tooltip:
                          '${color == Colors.amber ? 'Gold' : color == Colors.green ? 'Green' : color == Colors.blue ? 'Blue' : 'Pink'} highlight',
                      icon: Icon(Icons.circle, color: color),
                      onPressed: () async {
                        await colorPassage(verse, color.toARGB32());
                        if (sheetContext.mounted && saveError == null) {
                          Navigator.pop(sheetContext);
                        }
                      },
                    ),
                  IconButton(
                    tooltip: 'Remove highlight',
                    icon: const Icon(Icons.format_color_reset),
                    onPressed: () async {
                      await colorPassage(verse, null);
                      if (sheetContext.mounted && saveError == null) {
                        Navigator.pop(sheetContext);
                      }
                    },
                  ),
                ],
              ),
            ])),
      );

  Widget verseTile(String verse) => Builder(
        builder: (context) => Padding(
          key: verseAnchors.putIfAbsent(verse, () => GlobalKey()),
          padding: const EdgeInsets.only(bottom: 4),
          child: InkWell(
            key: ValueKey('verse-$verse'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => showVerseActions(context, verse),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: BoxDecoration(
                border: verse == focusedVerse ||
                        (selectedPassage != null &&
                            Bible.overlaps(selectedPassage!, verse))
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary, width: 2)
                    : null,
                color: selectedPassage != null &&
                        Bible.overlaps(selectedPassage!, verse)
                    ? Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withAlpha(180)
                    : verseHighlight(verse)?.withAlpha(65),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${bible!.verse(verse).number}  ',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                            fontFamily: 'sans-serif',
                          ),
                        ),
                        TextSpan(text: bible!.verse(verse).text),
                        if (relatedReferences(verse, notes.keys).isNotEmpty)
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: IconButton(
                              key: ValueKey('verse-note-$verse'),
                              tooltip: 'Open note',
                              iconSize: 18,
                              visualDensity: VisualDensity.compact,
                              color: Theme.of(context).colorScheme.primary,
                              onPressed: () {
                                final references =
                                    relatedReferences(verse, notes.keys);
                                if (references.length == 1) {
                                  annotate(references.first);
                                } else {
                                  showVerseActions(context, verse);
                                }
                              },
                              icon: const Icon(Icons.sticky_note_2_outlined),
                            ),
                          ),
                      ],
                    ),
                    style: TextStyle(
                      fontFamily: 'SourceSerif4',
                      fontSize: fontSize,
                      height: 1.7,
                    ),
                  ),
                  if (relatedReferences(verse, saved).isNotEmpty)
                    const Icon(Icons.bookmark, size: 16),
                ],
              ),
            ),
          ),
        ),
      );

  Widget library(BuildContext context) {
    final references = {...saved, ...notes.keys, ...highlights.keys}.toList()
      ..sort();
    return centered(
      ListView(
        padding: const EdgeInsets.all(28),
        children: [
          Text(
            'Your reflections',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Card(
              child: ListTile(
                  leading: const Icon(Icons.spa_outlined),
                  title: const Text('My time with God & prayers'),
                  subtitle: const Text(
                      'Guided sessions, drafts, and your prayer journal'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: openGrowthPage)),
          const SizedBox(height: 16),
          if (references.isEmpty)
            const Text(
              'A space for the words you want to return to. Tap a verse in the reader to begin.',
            ),
          for (final verse in references) ...[
            Text(
              '${bible!.reference(verse)} · ${bible!.abbreviation}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            verseTile(verse),
          ],
        ],
      ),
    );
  }

  Widget settings(BuildContext context) => centered(
        ListView(
          padding: const EdgeInsets.all(28),
          children: [
            Text(
              'Make room for reflection',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            if (focusAvailable)
              ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: const Text('Focus Mode'),
                  subtitle: const Text('Read before opening selected apps'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: openFocusPage),
            ListTile(
              leading: const Icon(Icons.translate),
              title: const Text('Bible translations'),
              subtitle: Text('${bible!.abbreviation} · ${bible!.language}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => manageTranslations(context),
            ),
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Backup & restore'),
              subtitle:
                  const Text('Export or restore your personal reading data'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => manageBackups(context),
            ),
            ListTile(
              leading: const Icon(Icons.headphones_outlined),
              title: const Text('Audio narration'),
              subtitle: const Text('WEB & BSB · Internet required'),
              trailing: const Icon(Icons.info_outline),
              onTap: () => audioInfo(context),
            ),
            SwitchListTile(
                secondary: const Icon(Icons.unfold_more_rounded),
                title: const Text('Follow audio'),
                subtitle: const Text(
                    'Scroll with chapter playback. Approximate timing; manual scrolling pauses following.'),
                value: followAudio,
                onChanged: (value) {
                  if (value != followAudio) {
                    toggleAudioFollowing(enabled: value);
                  }
                }),
            SwitchListTile(
              title: const Text('Dark theme'),
              value: dark,
              onChanged: (value) =>
                  updatePreference('dark', '$value', () => dark = value),
            ),
            const ListTile(title: Text('Reading font size')),
            Slider(
              label: '${fontSize.round()}',
              value: fontSize,
              min: 16,
              max: 32,
              divisions: 16,
              onChanged: (value) => updatePreference(
                  'fontSize', '$value', () => fontSize = value),
            ),
            Text(
              'Pause. Reflect. Grow.',
              style: TextStyle(fontFamily: 'SourceSerif4', fontSize: fontSize),
            ),
            const SizedBox(height: 32),
            TextButton(
              onPressed: () =>
                  showLicensePage(context: context, applicationName: 'SELAH'),
              child: const Text('Font & app licenses'),
            ),
            TextButton(
              onPressed: () => showCopyright(context),
              child: const Text('Bible copyright & license'),
            ),
            const Text(
              'English interface · Complete Cebuano Bible included\nNo account required.\nNotes, bookmarks, highlights, preferences, progress, and history are saved locally. Use Backup & restore to keep a copy outside the app. Clearing app or browser site data removes local records.',
            ),
          ],
        ),
      );
}
