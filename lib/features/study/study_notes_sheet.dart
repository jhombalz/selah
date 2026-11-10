import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/bible.dart';
import '../../data/commentary.dart';
import '../../data/scripture_range.dart';
import '../../data/user_database.dart';
import '../common/selah_dialog.dart';

Future<void> showStudyNotes(BuildContext context, Bible bible,
        UserDatabase database, String reference) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        constraints: const BoxConstraints(maxWidth: 720),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (_) => StudyNotesSheet(
            bible: bible, database: database, reference: reference));

class StudyNotesSheet extends StatefulWidget {
  final Bible bible;
  final UserDatabase database;
  final String reference;
  final StudyNotesRepository? repository;
  const StudyNotesSheet(
      {super.key,
      required this.bible,
      required this.database,
      required this.reference,
      this.repository});
  @override
  State<StudyNotesSheet> createState() => _StudyNotesSheetState();
}

class _StudyNotesSheetState extends State<StudyNotesSheet> {
  late final repository =
      widget.repository ?? StudyNotesRepository(widget.database);
  late final range = ScriptureRange.parse(widget.reference);
  StudyChapter? chapter;
  String? error;
  bool loading = true, wholeChapter = false, removed = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    repository.dispose();
    super.dispose();
  }

  Future<void> load({bool refresh = false}) async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final result =
          await repository.load(range.book, range.chapter, refresh: refresh);
      if (mounted) {
        setState(() {
          chapter = result;
          loading = false;
          removed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error =
              'Study notes could not be loaded. Connect to the internet to open this chapter for the first time, then try again.';
        });
      }
    }
  }

  Future<void> openLink(String address) async {
    try {
      if (await launchUrl(Uri.parse(address),
          mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {/* The displayed address can still be copied. */}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Could not open the link. You can copy the address shown.')));
    }
  }

  void sourceInfo() => showDialog<void>(
      context: context,
      builder: (context) => SelahDialog(
            title: const Text('Source and license'),
            content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(studyNotesName,
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  const Text(
                      'Tyndale Open Resources · Tyndale House Publishers\nLicensed under Creative Commons Attribution-ShareAlike 4.0 International. Study-note text is displayed unchanged in plain text from the Free Use Bible API. No AI summaries or translations are generated.'),
                  if (chapter?.licenseNotice.isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    SelectableText(chapter!.licenseNotice)
                  ],
                  if (chapter?.licenseNotes.isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    SelectableText(chapter!.licenseNotes)
                  ],
                  const SizedBox(height: 12),
                  TextButton.icon(
                      onPressed: () => openLink(studyNotesSource),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Tyndale Open Resources')),
                  const SelectableText(studyNotesSource),
                  TextButton.icon(
                      onPressed: () => openLink(studyNotesLicense),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('CC BY-SA 4.0 license')),
                  const SelectableText(studyNotesLicense),
                  TextButton.icon(
                      onPressed: () => openLink(
                          'https://bible.helloao.org/docs/reference/commentaries/'),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Free Use Bible API')),
                  const Text(
                      'Opened chapters are cached on this device (up to 100 recent chapters). They are separate from personal notes and Bible backups. This initial version matches range notes that start in the current chapter.'),
                ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'))
            ],
          ));
  Future<void> removeOffline() async {
    try {
      await repository.remove(range.book, range.chapter);
      if (mounted) setState(() => removed = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('The offline copy could not be removed. Please retry.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final notes = chapter?.notes
            .where((n) => wholeChapter || n.matches(range))
            .toList() ??
        <StudyNote>[];
    if (!wholeChapter) {
      notes.sort((a, b) {
        final aDistance = (range.start - a.anchor).clamp(0, 10000);
        final bDistance = (range.start - b.anchor).clamp(0, 10000);
        final byDistance = aDistance.compareTo(bDistance);
        return byDistance != 0 ? byDistance : a.anchor.compareTo(b.anchor);
      });
    }
    return Directionality(
        textDirection: TextDirection.ltr,
        child: SafeArea(
            top: false,
            child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .86,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 12, 16),
                          child: Row(children: [
                            Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: colors.primaryContainer,
                                    borderRadius: BorderRadius.circular(16)),
                                child: Icon(Icons.menu_book_outlined,
                                    color: colors.primary)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text('Study notes',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                              fontFamily: 'SourceSerif4')),
                                  Text(
                                      '${widget.bible.reference(widget.reference)} · English',
                                      style: TextStyle(
                                          color: colors.onSurfaceVariant,
                                          fontSize: 12)),
                                ])),
                            IconButton(
                                tooltip: 'Close study notes',
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close_rounded)),
                          ])),
                      const Divider(height: 1),
                      if (loading) const LinearProgressIndicator(),
                      Expanded(
                          child: SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(studyNotesName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    const SizedBox(height: 6),
                                    Text(
                                        'Commentary by Tyndale · explanations and interpretation, separate from Scripture.',
                                        style: TextStyle(
                                            color: colors.onSurfaceVariant,
                                            fontSize: 12)),
                                    const SizedBox(height: 16),
                                    SegmentedButton<bool>(
                                        segments: const [
                                          ButtonSegment(
                                              value: false,
                                              label: Text('Selected passage')),
                                          ButtonSegment(
                                              value: true,
                                              label: Text('Whole chapter'))
                                        ],
                                        selected: {
                                          wholeChapter
                                        },
                                        onSelectionChanged: (value) => setState(
                                            () => wholeChapter = value.single)),
                                    const SizedBox(height: 16),
                                    if (error != null)
                                      Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                              color: colors.surfaceContainerLow,
                                              borderRadius:
                                                  BorderRadius.circular(18)),
                                          child: Column(children: [
                                            const Icon(
                                                Icons.cloud_off_outlined),
                                            const SizedBox(height: 8),
                                            Text(error!),
                                            TextButton(
                                                onPressed: loading
                                                    ? null
                                                    : () => load(refresh: true),
                                                child: const Text('Try again'))
                                          ])),
                                    if (chapter != null) ...[
                                      Text(
                                          removed
                                              ? 'Offline copy removed · notes remain visible this session.'
                                              : chapter!.cacheFailed
                                                  ? 'Notes loaded · offline saving was unavailable.'
                                                  : chapter!.cached
                                                      ? 'Saved notes · available offline'
                                                      : 'Downloaded · saved for offline reading',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: colors.onSurfaceVariant)),
                                      if (chapter!.refreshFailed)
                                        const Padding(
                                            padding: EdgeInsets.only(top: 8),
                                            child: Text(
                                                'Could not refresh. Showing your saved study notes.')),
                                      const SizedBox(height: 16),
                                      if (notes.isEmpty && !loading)
                                        Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 24),
                                            child: Column(children: [
                                              Icon(Icons.menu_book_outlined,
                                                  size: 40,
                                                  color: colors.primary),
                                              const SizedBox(height: 12),
                                              Text(
                                                  wholeChapter ||
                                                          chapter!.notes.isEmpty
                                                      ? 'This source has no study notes for this chapter.'
                                                      : 'No study notes are linked to this selection. Try Whole chapter for nearby context.',
                                                  textAlign: TextAlign.center),
                                            ])),
                                      for (final note in notes)
                                        Container(
                                            margin: const EdgeInsets.only(
                                                bottom: 14),
                                            padding: const EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                                color:
                                                    colors.surfaceContainerLow,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                    color:
                                                        colors.outlineVariant)),
                                            child: SelectableText(note.text,
                                                style: const TextStyle(
                                                    fontFamily: 'SourceSerif4',
                                                    fontSize: 18,
                                                    height: 1.6))),
                                    ],
                                  ]))),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              border: Border(
                                  top: BorderSide(
                                      color: colors.outlineVariant))),
                          child: Row(children: [
                            Expanded(
                                child: TextButton.icon(
                                    onPressed: sourceInfo,
                                    icon: const Icon(Icons.info_outline,
                                        size: 18),
                                    label: const Text('Source & license'))),
                            if (chapter != null &&
                                !removed &&
                                !chapter!.cacheFailed)
                              IconButton(
                                  tooltip: 'Remove offline copy',
                                  onPressed: loading ? null : removeOffline,
                                  icon: const Icon(Icons.offline_pin_outlined)),
                            IconButton(
                                tooltip: 'Refresh study notes',
                                onPressed:
                                    loading ? null : () => load(refresh: true),
                                icon: const Icon(Icons.refresh_rounded)),
                          ])),
                    ]))));
  }
}
