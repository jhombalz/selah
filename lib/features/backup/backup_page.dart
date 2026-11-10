import '../common/selah_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../data/bible.dart';
import '../../data/user_backup.dart';
import 'backup_files.dart';

class BackupPage extends StatefulWidget {
  final Bible canon;
  final Future<UserBackup> Function() capture;
  final Future<RestoreResult> Function(UserBackup, RestoreMode) restore;
  final BackupFiles? files;
  const BackupPage(
      {super.key,
      required this.canon,
      required this.capture,
      required this.restore,
      this.files});
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  late final BackupFiles files = widget.files ?? DeviceBackupFiles();
  UserBackup? backup;
  String? filename;
  String? message;
  String? error;
  RestoreMode mode = RestoreMode.merge;
  bool busy = false;

  Future<void> export() async {
    setState(() {
      busy = true;
      error = null;
      message = null;
    });
    try {
      final snapshot = await widget.capture();
      final name =
          'the-bible-backup-${snapshot.createdAt.toIso8601String().replaceAll(':', '-').replaceAll('.', '-')}.json';
      final saved = await files.save(name, snapshot.encode());
      if (mounted) {
        setState(() => message = !saved
            ? 'Export cancelled.'
            : kIsWeb
                ? 'Backup download requested. Check your browser’s downloads.'
                : 'Backup saved.');
      }
    } on FormatException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } catch (_) {
      if (mounted) {
        setState(
            () => error = 'The backup could not be saved. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> choose() async {
    setState(() {
      busy = true;
      error = null;
      message = null;
      backup = null;
      filename = null;
    });
    try {
      final picked = await files.pick();
      if (picked == null) return;
      final decoded = UserBackup.decode(picked.bytes, widget.canon);
      if (mounted) {
        setState(() {
          backup = decoded;
          filename = picked.name;
          mode = RestoreMode.merge;
        });
      }
    } on FormatException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'This file could not be opened. Choose a readable Bible backup file.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> apply() async {
    final selected = backup;
    if (selected == null || busy) return;
    if (mode == RestoreMode.replace) {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => SelahDialog(
                title: const Text('Replace local user data?'),
                content: const Text(
                    'Notes, bookmarks, highlights, settings, history, progress, guided sessions, and prayers will be replaced by this backup. Items absent from the backup will be removed. Older backups contain no journals. Your downloaded Bible translations will stay installed.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Replace data'))
                ],
              ));
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      busy = true;
      message = null;
      error = null;
    });
    try {
      final result = await widget.restore(selected, mode);
      if (mounted) {
        setState(() {
          message =
              '${mode == RestoreMode.merge ? 'Backup merged' : 'Backup restored'}. You now have ${result.data.notes.length} notes and ${result.data.bookmarks.length} bookmarks.${result.translationFallback ? ' The backup’s selected translation is unavailable, so reading uses the bundled Cebuano Bible.' : ''}';
          backup = null;
          filename = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Restore could not finish. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Backup & restore')),
        body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(padding: const EdgeInsets.all(24), children: [
                  const Text('Keep your reflections with you.',
                      style:
                          TextStyle(fontFamily: 'SourceSerif4', fontSize: 28)),
                  const SizedBox(height: 12),
                  const Text(
                      'Export notes, bookmarks, highlights, reading history, progress, preferences, guided sessions, and prayers to a file. Bible texts and downloaded translations are not included.'),
                  const SizedBox(height: 8),
                  const Text(
                      'Backups are unencrypted JSON files stored wherever you choose. No account or internet connection is required.',
                      style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 24),
                  if (busy) const LinearProgressIndicator(),
                  if (error != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))),
                  if (message != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(message!)),
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    FilledButton.icon(
                        onPressed: busy ? null : export,
                        icon: const Icon(Icons.file_download_outlined),
                        label: const Text('Export backup')),
                    OutlinedButton.icon(
                        onPressed: busy ? null : choose,
                        icon: const Icon(Icons.file_upload_outlined),
                        label: const Text('Choose backup file')),
                  ]),
                  if (backup != null) ...[
                    const SizedBox(height: 24),
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Backup preview',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge),
                                  const SizedBox(height: 12),
                                  Text(filename!),
                                  Text(
                                      'Created ${MaterialLocalizations.of(context).formatFullDate(backup!.createdAt.toLocal())}'),
                                  const SizedBox(height: 12),
                                  Text(
                                      '${backup!.data.notes.length} notes · ${backup!.data.bookmarks.length} bookmarks\n${backup!.data.highlights.length} highlights · ${backup!.data.history.length} history entries\n${backup!.data.history.where((entry) => entry.completed).length} completed chapters · ${backup!.data.preferences.length} preferences\n${backup!.data.growth.where((entry) => entry.kind == 'session').length} guided sessions · ${backup!.data.growth.where((entry) => entry.kind == 'prayer').length} prayers'),
                                  const SizedBox(height: 20),
                                  SegmentedButton<RestoreMode>(
                                      segments: const [
                                        ButtonSegment(
                                            value: RestoreMode.merge,
                                            label: Text('Merge')),
                                        ButtonSegment(
                                            value: RestoreMode.replace,
                                            label: Text('Replace'))
                                      ],
                                      selected: {
                                        mode
                                      },
                                      onSelectionChanged: busy
                                          ? null
                                          : (value) => setState(
                                              () => mode = value.single)),
                                  const SizedBox(height: 12),
                                  Text(mode == RestoreMode.merge
                                      ? 'Adds missing items. Existing notes, settings, and highlight colors win conflicts. Completed chapters are combined. Restoring the same file again does not duplicate records.'
                                      : 'Replaces local user data with the backup. Notes and progress absent from the backup will be removed. Downloaded Bibles stay installed.'),
                                  const SizedBox(height: 16),
                                  FilledButton(
                                      onPressed: busy ? null : apply,
                                      child: Text(mode == RestoreMode.merge
                                          ? 'Merge backup'
                                          : 'Replace with backup')),
                                ]))),
                  ],
                ]))),
      ));
}
