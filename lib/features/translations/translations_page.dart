import '../common/selah_dialog.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import '../../data/bible.dart';
import '../../data/translations.dart';
import '../../data/user_database.dart';

class TranslationsPage extends StatefulWidget {
  final UserDatabase database;
  final Bible bundled;
  final String activeId;
  final Future<void> Function(Bible) onSelect;
  final Future<void> Function(String) onRemove;
  const TranslationsPage(
      {super.key,
      required this.database,
      required this.bundled,
      required this.activeId,
      required this.onSelect,
      required this.onRemove});
  @override
  State<TranslationsPage> createState() => _TranslationsPageState();
}

class _TranslationsPageState extends State<TranslationsPage> {
  final downloader = TranslationDownloader();
  Set<String> installed = {'cebocb'};
  late String active;
  String? downloading;
  double? progress;
  String status = '';
  String? error;
  bool loading = true;
  bool saving = false;
  String language = 'All';
  @override
  void initState() {
    super.initState();
    active = widget.activeId;
    refresh();
  }

  @override
  void dispose() {
    downloader.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    try {
      final result = await widget.database.installedTranslations();
      if (mounted) {
        setState(() {
          installed = {'cebocb', ...result.keys};
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Installed translations could not be read. Please retry.';
          loading = false;
        });
      }
    }
  }

  Future<void> download(TranslationSpec spec) async {
    setState(() {
      downloading = spec.id;
      progress = null;
      error = null;
      status = 'Connecting';
    });
    try {
      final bible =
          await downloader.download(spec, widget.bundled, (value, label) {
        if (mounted) {
          setState(() {
            progress = value;
            status = label;
          });
        }
      });
      if (!mounted) return;
      setState(() {
        saving = true;
        progress = .97;
        status = 'Saving for offline reading';
      });
      final content = jsonEncode(bible.toJson());
      await widget.database.installTranslation(
          spec.id, content, sha256.convert(utf8.encode(content)).toString());
      await refresh();
    } on DownloadCancelled {
      if (mounted) {
        setState(
            () => error = 'Download cancelled. You can start again anytime.');
      }
    } on FormatException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'Download could not finish. Check your connection and available storage, then retry. Your installed Bibles are unchanged.');
      }
    } finally {
      if (mounted) {
        setState(() {
          downloading = null;
          saving = false;
        });
      }
    }
  }

  Future<void> select(TranslationSpec spec) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final bible = spec.id == 'cebocb'
          ? widget.bundled
          : await loadInstalledBible(widget.database, spec.id);
      if (bible == null) throw StateError('Not installed');
      await widget.onSelect(bible);
      if (mounted) setState(() => active = spec.id);
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'This translation could not be opened. Try removing it and downloading it again.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> remove(TranslationSpec spec) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => SelahDialog(
              title: Text('Remove ${spec.abbreviation}?'),
              content: Text(
                  'Your notes, bookmarks, highlights, and progress will be kept.${active == spec.id ? ' Reading will switch to the bundled Cebuano Bible.' : ''}'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Remove'))
              ],
            ));
    if (confirmed != true || !mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.onRemove(spec.id);
      if (mounted && active == spec.id) setState(() => active = 'cebocb');
      await refresh();
    } catch (_) {
      if (mounted) {
        setState(() =>
            error = 'The translation could not be removed. Please retry.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Bible translations')),
        body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(padding: const EdgeInsets.all(24), children: [
                  const Text('Your Bible, in your language',
                      style:
                          TextStyle(fontFamily: 'SourceSerif4', fontSize: 28)),
                  const SizedBox(height: 12),
                  const Text(
                      'The Cebuano Bible is always included. Download additional translations once, then read and search them offline. Downloads need an internet connection.'),
                  const SizedBox(height: 20),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final value in [
                      'All',
                      'Cebuano',
                      'English',
                      'Tagalog'
                    ])
                      ChoiceChip(
                          label: Text(value),
                          selected: language == value,
                          onSelected: (_) => setState(() => language = value)),
                  ]),
                  const SizedBox(height: 12),
                  if (loading) const LinearProgressIndicator(),
                  if (error != null) ...[
                    Text(error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                    TextButton(
                        onPressed: loading ? null : refresh,
                        child: const Text('Refresh installed translations')),
                    const SizedBox(height: 12)
                  ],
                  for (final spec in translationCatalog.where(
                      (spec) => language == 'All' || spec.language == language))
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(spec.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge),
                                  const SizedBox(height: 6),
                                  Text(
                                      '${spec.language} · ${spec.abbreviation} · ${active == spec.id ? 'Selected' : installed.contains(spec.id) ? 'Available offline' : 'Not downloaded'}'),
                                  if (spec.id == 'web' || spec.id == 'bsb')
                                    const Padding(
                                        padding: EdgeInsets.only(top: 8),
                                        child: Text(
                                            'Recorded narration available online')),
                                  if (spec.id == 'tglulb')
                                    const Padding(
                                        padding: EdgeInsets.only(top: 8),
                                        child: Text(
                                            'Text edition · No recorded audio configured')),
                                  if (spec.id == 'cebocb')
                                    const Padding(
                                        padding: EdgeInsets.only(top: 8),
                                        child: Text(
                                            'Included with the app · Cannot be removed')),
                                  const SizedBox(height: 12),
                                  if (downloading == spec.id) ...[
                                    LinearProgressIndicator(value: progress),
                                    const SizedBox(height: 8),
                                    Text(
                                        '$status${progress == null ? '' : ' · ${(progress! * 100).round()}%'}'),
                                    TextButton(
                                        onPressed:
                                            saving ? null : downloader.cancel,
                                        child: const Text('Cancel download')),
                                  ] else
                                    Wrap(spacing: 12, runSpacing: 8, children: [
                                      if (installed.contains(spec.id))
                                        FilledButton(
                                            onPressed: loading ||
                                                    downloading != null ||
                                                    active == spec.id
                                                ? null
                                                : () => select(spec),
                                            child: Text(active == spec.id
                                                ? 'Selected'
                                                : 'Use ${spec.abbreviation}'))
                                      else
                                        FilledButton.icon(
                                            onPressed:
                                                loading || downloading != null
                                                    ? null
                                                    : () => download(spec),
                                            icon: const Icon(
                                                Icons.download_outlined),
                                            label: Text(
                                                'Download ${spec.abbreviation}')),
                                      if (installed.contains(spec.id) &&
                                          spec.id != 'cebocb')
                                        TextButton(
                                            onPressed:
                                                loading || downloading != null
                                                    ? null
                                                    : () => remove(spec),
                                            child:
                                                const Text('Remove download')),
                                    ]),
                                  ExpansionTile(
                                      tilePadding: EdgeInsets.zero,
                                      title: const Text('Source & license'),
                                      children: [
                                        Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 12),
                                            child: SelectableText(
                                                '${spec.license}\n${spec.source}'))
                                      ]),
                                ]))),
                ]))),
      ));
}
