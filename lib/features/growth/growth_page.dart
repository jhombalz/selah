import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/bible.dart';
import '../../data/growth_entry.dart';
import '../../data/user_database.dart';
import 'growth_catalog.dart';
import 'growth_platform.dart';
import 'growth_share.dart';

class GrowthPage extends StatefulWidget {
  final UserDatabase database;
  final Bible bible;
  final String currentReference;
  final void Function(GrowthEntry) onRead;
  const GrowthPage(
      {super.key,
      required this.database,
      required this.bible,
      required this.currentReference,
      required this.onRead});
  @override
  State<GrowthPage> createState() => _GrowthPageState();
}

class _GrowthPageState extends State<GrowthPage> {
  List<GrowthEntry> entries = [];
  String? error;
  bool loading = true, busy = false;
  Map<dynamic, dynamic> reminder = {};
  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final data = await widget.database.growthEntries();
      final settings = await GrowthReminders.status();
      if (mounted) {
        setState(() {
          entries = data;
          reminder = settings;
          loading = false;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Your journal could not be loaded. Please retry.';
        });
      }
    }
  }

  Future<void> open(GrowthEntry entry) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => GrowthEditor(
            database: widget.database,
            bible: widget.bible,
            entry: entry,
            onRead: widget.onRead)));
    if (mounted) await reload();
  }

  Future<void> start({String? theme, bool prayer = false}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final card = theme == null
          ? null
          : chooseGrowthCard(theme, await widget.database.growthSeen());
      final entry = GrowthEntry.create(
          kind: prayer ? 'prayer' : 'session',
          title: prayer ? 'My prayer' : card?.title ?? 'My time with God',
          translation: widget.bible.id,
          reference: prayer ? null : card?.reference ?? widget.currentReference,
          cardId: card?.id);
      await widget.database.transaction(() async {
        await widget.database.saveGrowth(entry);
        if (card != null) await widget.database.markGrowthSeen(card.id);
      });
      if (mounted) await open(entry);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not start this entry. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> delete(GrowthEntry entry) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Delete this entry?'),
                content: const Text(
                    'This removes this journal entry from this device. Verse notes stay unchanged.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'))
                ]));
    if (confirmed != true) return;
    try {
      await widget.database.deleteGrowth(entry.id);
      await reload();
    } catch (_) {
      if (mounted) setState(() => error = 'Could not delete this entry.');
    }
  }

  Future<void> setReminder(bool enabled, {String slot = 'morning'}) async {
    final prefix = slot == 'bedtime' ? 'bedtime_' : '';
    var time = TimeOfDay(
        hour:
            (reminder['${prefix}hour'] as int?) ?? (slot == 'bedtime' ? 21 : 8),
        minute: (reminder['${prefix}minute'] as int?) ?? 0);
    if (enabled) {
      final selected =
          await showTimePicker(context: context, initialTime: time);
      if (selected == null) return;
      time = selected;
    }
    try {
      final accepted = await GrowthReminders.configure(
          enabled, time.hour, time.minute,
          slot: slot);
      if (mounted && enabled && !accepted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Notifications are not enabled. You can allow them in Android settings.')));
      }
      await reload();
    } catch (_) {
      if (mounted) setState(() => error = 'The reminder could not be updated.');
    }
  }

  Widget reminderCard(String slot, String title, IconData icon) {
    final prefix = slot == 'bedtime' ? 'bedtime_' : '';
    final enabled = reminder['${prefix}enabled'] == true;
    final time = TimeOfDay(
        hour:
            (reminder['${prefix}hour'] as int?) ?? (slot == 'bedtime' ? 21 : 8),
        minute: (reminder['${prefix}minute'] as int?) ?? 0);
    return Card(
        child: Column(children: [
      SwitchListTile(
          secondary: Icon(icon),
          title: Text(title),
          subtitle: const Text('A gentle invitation to read a verse.'),
          value: enabled,
          onChanged: (value) => setReminder(value, slot: slot)),
      ListTile(
          leading: const Icon(Icons.schedule_outlined),
          title: Text(time.format(context)),
          subtitle: Text(
              enabled ? 'Tap to change time' : 'Choose a time when enabling'),
          trailing: const Icon(Icons.chevron_right),
          onTap: enabled ? () => setReminder(true, slot: slot) : null),
    ]));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('My time with God')),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(padding: const EdgeInsets.all(24), children: [
                Text('A quiet moment.\nA faithful next step.',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontFamily: 'SourceSerif4')),
                const SizedBox(height: 12),
                const Text(
                    'Pause, read, reflect, pray, and carry one small response into your day. Skip any step. Your writing stays on this device.'),
                const SizedBox(height: 20),
                FilledButton.icon(
                    onPressed: busy ? null : () => start(),
                    icon: const Icon(Icons.auto_stories_outlined),
                    label: const Text('Begin with my current chapter')),
                const SizedBox(height: 28),
                Text('What are you carrying today?',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text(
                    'Optional. These themes suggest Scripture passages, not a diagnosis.'),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final theme in growthThemes)
                    ActionChip(
                        label: Text(theme),
                        onPressed: busy ? null : () => start(theme: theme))
                ]),
                const SizedBox(height: 8),
                const Text(
                    'Or skip the check-in and begin with your current chapter.',
                    style: TextStyle(fontSize: 12)),
                const SizedBox(height: 28),
                Row(children: [
                  Expanded(
                      child: Text('My prayers & sessions',
                          style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(
                      tooltip: 'Write a prayer',
                      onPressed: busy ? null : () => start(prayer: true),
                      icon: const Icon(Icons.add))
                ]),
                if (loading) const LinearProgressIndicator(),
                if (error != null)
                  TextButton(onPressed: reload, child: Text(error!)),
                if (!loading && entries.isEmpty)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                          'Your saved moments will appear here. There is no streak to maintain.')),
                for (final entry in entries)
                  Card(
                      child: ListTile(
                          leading: Icon(entry.kind == 'prayer'
                              ? Icons.favorite_outline
                              : Icons.book_outlined),
                          title: Text(entry.title),
                          subtitle: Text(
                              '${entry.kind == 'prayer' ? entry.status : entry.completed ? 'Saved moment' : 'Continue draft'} · ${MaterialLocalizations.of(context).formatMediumDate(entry.updatedAt.toLocal())}'),
                          onTap: () => open(entry),
                          trailing: IconButton(
                              tooltip: 'Delete entry',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => delete(entry)))),
                const SizedBox(height: 24),
                if (GrowthReminders.supported)
                  reminderCard('morning', 'Morning verse reminder',
                      Icons.wb_sunny_outlined),
                if (GrowthReminders.supported)
                  reminderCard(
                      'bedtime', 'Before sleep', Icons.bedtime_outlined),
                if (GrowthReminders.supported)
                  const Text(
                      'Optional, offline reminders in your device’s local time. Tap a notification to open the Bible. Android may delay delivery to save battery. No private writing appears in notifications.',
                      style: TextStyle(fontSize: 12)),
                const SizedBox(height: 16),
                const Text(
                    'Private does not mean encrypted. Journals are included in your unencrypted backup files. Use Backup & restore to keep a copy.',
                    style: TextStyle(fontSize: 12)),
              ]))));
}

class GrowthEditor extends StatefulWidget {
  final UserDatabase database;
  final Bible bible;
  final GrowthEntry entry;
  final void Function(GrowthEntry) onRead;
  const GrowthEditor(
      {super.key,
      required this.database,
      required this.bible,
      required this.entry,
      required this.onRead});
  @override
  State<GrowthEditor> createState() => _GrowthEditorState();
}

class _GrowthEditorState extends State<GrowthEditor>
    with WidgetsBindingObserver {
  late final reflection = TextEditingController(text: widget.entry.reflection);
  late final prayer = TextEditingController(text: widget.entry.prayer);
  late final action = TextEditingController(text: widget.entry.action);
  late final update = TextEditingController(text: widget.entry.updateDraft);
  Future<void> writes = Future.value();
  String? error;
  bool saving = false, allowPop = false, closing = false;
  GrowthEntry get entry => widget.entry;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<bool> save() async {
    entry.reflection = reflection.text;
    entry.prayer = prayer.text;
    entry.action = action.text;
    entry.updateDraft = update.text;
    entry.updatedAt = DateTime.now().toUtc();
    final snapshot = GrowthEntry.fromJson(entry.toJson());
    final pending = writes.then((_) => widget.database.saveGrowth(snapshot));
    writes = pending.catchError((Object _) {});
    if (mounted) setState(() => saving = true);
    try {
      await pending;
      if (mounted) {
        setState(() {
          error = null;
          saving = false;
        });
      }
      return true;
    } catch (_) {
      if (mounted) {
        setState(() {
          error =
              'Your latest changes could not be saved. Please retry before leaving.';
          saving = false;
        });
      }
      return false;
    }
  }

  Future<void> close() async {
    if (closing) return;
    closing = true;
    if (!await save() || !mounted) {
      closing = false;
      return;
    }
    setState(() => allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(save());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    reflection.dispose();
    prayer.dispose();
    action.dispose();
    update.dispose();
    super.dispose();
  }

  Widget field(String label, TextEditingController controller,
          {String? hint}) =>
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: TextField(
              controller: controller,
              minLines: 4,
              maxLines: 10,
              maxLength: 100000,
              decoration: InputDecoration(
                  labelText: label,
                  hintText: hint,
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                  counterText: ''),
              onChanged: (_) => unawaited(save())));
  Future<void> next() async {
    final finishing = entry.step == 4;
    if (finishing) {
      entry.completed = true;
    } else {
      entry.step++;
    }
    if (await save() && mounted && finishing) await close();
  }

  @override
  Widget build(BuildContext context) {
    final card = growthCard(entry.cardId);
    final session = entry.kind == 'session';
    final steps = ['Pause', 'Read', 'Reflect', 'Pray', 'Live'];
    return PopScope(
        canPop: allowPop,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(close());
        },
        child: Scaffold(
            appBar: AppBar(
                title: Text(session ? entry.title : 'My prayer'),
                actions: [
                  IconButton(
                      tooltip: 'Preview sharing',
                      icon: const Icon(Icons.ios_share),
                      onPressed: () async {
                        if (await save() && context.mounted) {
                          await previewGrowthShare(
                              context, widget.bible, entry);
                        }
                      }),
                ]),
            body: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child:
                        ListView(padding: const EdgeInsets.all(24), children: [
                      if (session) ...[
                        Wrap(spacing: 8, children: [
                          for (var i = 0; i < steps.length; i++)
                            ChoiceChip(
                                label: Text(steps[i]),
                                selected: entry.step == i,
                                onSelected: (_) {
                                  setState(() => entry.step = i);
                                  unawaited(save());
                                })
                        ]),
                        const SizedBox(height: 24),
                        if (entry.step == 0) ...[
                          const Icon(Icons.spa_outlined, size: 44),
                          const SizedBox(height: 20),
                          const Text('Pause here.',
                              style: TextStyle(
                                  fontFamily: 'SourceSerif4', fontSize: 32)),
                          const SizedBox(height: 12),
                          const Text(
                              'Take a breath. You do not need perfect words. You may ask God to help you listen and understand as you read.'),
                        ],
                        if (entry.step == 1) ...[
                          Text(widget.bible.reference(entry.reference!),
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 12),
                          Text(card?.context ??
                              'Read your current chapter at your own pace. Notice what the passage says before choosing a response.'),
                          const SizedBox(height: 12),
                          const Text(
                              'SELAH reflection guidance · original editorial content',
                              style: TextStyle(fontSize: 11)),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                              icon: const Icon(Icons.auto_stories_outlined),
                              label: const Text('Open passage in the Bible'),
                              onPressed: () async {
                                if (await save() && mounted) {
                                  widget.onRead(entry);
                                }
                              }),
                          const SizedBox(height: 12),
                          Text(
                              'Reading in ${widget.bible.abbreviation}. The full chapter remains available. ${entry.translation != widget.bible.id ? 'This session began in ${entry.translation}.' : ''}'),
                        ],
                        if (entry.step == 2) ...[
                          Text(
                              card?.question ??
                                  'What does this passage reveal about God, and what would you like to consider further?',
                              style: Theme.of(context).textTheme.titleLarge),
                          field('My reflection', reflection,
                              hint:
                                  'An observation, question, or honest response…'),
                        ],
                        if (entry.step == 3) ...[
                          Text(
                              card?.prayer ??
                                  'God, help me respond honestly to what I have read. Here is what I would like to bring to You…',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          const Text(
                              'A suggested starting point, in your own words.'),
                          field('My prayer', prayer),
                        ],
                        if (entry.step == 4) ...[
                          Text('One small response',
                              style: Theme.of(context).textTheme.headlineSmall),
                          Text(card?.action ??
                              'Is there a small act of love, gratitude, reconciliation, or care you want to choose?'),
                          field('My response', action),
                          if (entry.action.isNotEmpty)
                            CheckboxListTile(
                                value: entry.actionDone,
                                title: const Text('I took this step'),
                                onChanged: (value) {
                                  setState(() => entry.actionDone = value!);
                                  unawaited(save());
                                }),
                          const Text(
                              'You can leave this blank. A completed session is not a measure of faith.'),
                        ],
                        const SizedBox(height: 24),
                        Wrap(spacing: 12, runSpacing: 8, children: [
                          if (entry.step > 0)
                            TextButton(
                                onPressed: () {
                                  setState(() => entry.step--);
                                  unawaited(save());
                                },
                                child: const Text('Back')),
                          TextButton(
                              onPressed: next,
                              child: const Text('Skip this step')),
                          FilledButton(
                              onPressed: next,
                              child: Text(entry.step == 4
                                  ? 'Save this moment'
                                  : 'Continue')),
                        ]),
                      ] else ...[
                        Text('A place for honest prayer.',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontFamily: 'SourceSerif4')),
                        TextFormField(
                            initialValue: entry.title,
                            maxLength: 200,
                            decoration: const InputDecoration(
                                labelText: 'Prayer title', counterText: ''),
                            onChanged: (value) {
                              entry.title = value;
                              unawaited(save());
                            }),
                        DropdownButtonFormField<String>(
                            initialValue: entry.category,
                            decoration:
                                const InputDecoration(labelText: 'Category'),
                            items: [
                              for (final value in [
                                'Request',
                                'Gratitude',
                                'Lament',
                                'Waiting'
                              ])
                                DropdownMenuItem(
                                    value: value, child: Text(value))
                            ],
                            onChanged: (value) {
                              setState(() => entry.category = value!);
                              unawaited(save());
                            }),
                        field('My prayer', prayer),
                        DropdownButtonFormField<String>(
                            initialValue: entry.status,
                            decoration: const InputDecoration(
                                labelText: 'My prayer status'),
                            items: [
                              for (final value in [
                                'Still praying',
                                'Answered',
                                'Archived'
                              ])
                                DropdownMenuItem(
                                    value: value, child: Text(value))
                            ],
                            onChanged: (value) {
                              setState(() => entry.status = value!);
                              unawaited(save());
                            }),
                        const SizedBox(height: 12),
                        const Text(
                            'Only you choose this status. SELAH does not determine whether or how a prayer was answered.'),
                        const SizedBox(height: 24),
                        Text('Updates',
                            style: Theme.of(context).textTheme.titleLarge),
                        for (final item in entry.updates.reversed)
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(item.text),
                              subtitle: Text(MaterialLocalizations.of(context)
                                  .formatMediumDate(item.date.toLocal()))),
                        field('Add an update', update),
                        OutlinedButton(
                            onPressed: () async {
                              if (update.text.trim().isEmpty) return;
                              setState(() {
                                entry.updates.add((
                                  date: DateTime.now().toUtc(),
                                  text: update.text.trim()
                                ));
                                update.clear();
                              });
                              await save();
                            },
                            child: const Text('Save update')),
                      ],
                      const SizedBox(height: 24),
                      if (error != null)
                        Text(error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      Text(
                          saving
                              ? 'Saving…'
                              : error == null
                                  ? 'Saved on this device · included in your backup'
                                  : 'Changes need attention',
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 12),
                      OutlinedButton(
                          onPressed: close, child: const Text('Save & close')),
                    ])))));
  }
}
