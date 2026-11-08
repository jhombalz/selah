import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/bible.dart';
import '../../data/daily_verse.dart';

class DailyVerseCard extends StatefulWidget {
  final Bible bible;
  final DailyVerseRepository repository;
  final ValueChanged<String> onOpen;
  const DailyVerseCard(
      {super.key,
      required this.bible,
      required this.repository,
      required this.onOpen});

  @override
  State<DailyVerseCard> createState() => _DailyVerseCardState();
}

class _DailyVerseCardState extends State<DailyVerseCard>
    with WidgetsBindingObserver {
  Timer? timer;
  DateTime today = DateTime.now();
  DailyVerseChoice? choice;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
    scheduleRefresh();
  }

  Future<void> refresh() async {
    final request = ++generation;
    final date = DateTime.now();
    if (dailyVerseDay(date) != dailyVerseDay(today)) choice = null;
    setState(() => today = date);
    final result = await widget.repository.load(widget.bible, date);
    if (mounted && request == generation) setState(() => choice = result);
  }

  @override
  void didUpdateWidget(covariant DailyVerseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bible != widget.bible) {
      choice = null;
      refresh();
    }
  }

  void scheduleRefresh() {
    timer?.cancel();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1).difference(now);
    timer = Timer(
        midnight < const Duration(minutes: 1)
            ? midnight
            : const Duration(minutes: 1), () {
      if (!mounted) return;
      refresh();
      scheduleRefresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refresh();
      scheduleRefresh();
    } else {
      timer?.cancel();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reference =
        choice?.reference ?? dailyVerseReference(widget.bible, today);
    final verse = widget.bible.verse(reference);
    final parts = reference.split('.');
    final actualReference = '${parts[0]}.${parts[1]}.${verse.number}';
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('VERSE OF THE DAY',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 2,
                      color: Theme.of(context).colorScheme.primary)),
              const SizedBox(height: 8),
              Text(MaterialLocalizations.of(context).formatMediumDate(today)),
              const SizedBox(height: 16),
              Text(verse.text,
                  style: const TextStyle(
                      fontFamily: 'SourceSerif4', fontSize: 23, height: 1.6)),
              const SizedBox(height: 12),
              Text(
                  '${widget.bible.reference(actualReference)} · ${widget.bible.abbreviation}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextButton.icon(
                  onPressed: () => widget.onOpen(actualReference),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Read in context')),
            ])));
  }
}
