import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/bible.dart';

const dailyVerseReferences = [
  'JHN.3.16',
  'PSA.23.1',
  'PRO.3.5-6',
  'PHP.4.6-7',
  'ISA.40.31',
  'MAT.11.28',
  'ROM.8.28',
  'JOS.1.9',
  'PSA.46.1',
  'PHP.4.13',
  'LAM.3.22-23',
  'MAT.6.33',
  '1PE.5.7',
  'PSA.119.105',
  'JHN.14.27',
  'ROM.15.13',
  'ISA.41.10',
  'GAL.5.22-23',
  'HEB.11.1',
  'PSA.34.8',
  '2TI.1.7',
  'MIC.6.8',
  '1CO.13.4-7',
  'EPH.2.8-9',
  'JAS.1.5',
  'PSA.121.1-2',
  'COL.3.15',
  'ROM.12.2',
  'JHN.15.5',
  'PSA.100.5',
  'NUM.6.24-26',
];

/// Calendar arithmetic in UTC keeps the rotation independent of DST changes.
String dailyVerseReference(DateTime date) {
  final day = DateTime.utc(date.year, date.month, date.day)
      .difference(DateTime.utc(2026))
      .inDays;
  return dailyVerseReferences[day % dailyVerseReferences.length];
}

class DailyVerseCard extends StatefulWidget {
  final Bible bible;
  final ValueChanged<String> onOpen;
  const DailyVerseCard({super.key, required this.bible, required this.onOpen});

  @override
  State<DailyVerseCard> createState() => _DailyVerseCardState();
}

class _DailyVerseCardState extends State<DailyVerseCard>
    with WidgetsBindingObserver {
  Timer? timer;
  DateTime today = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    scheduleRefresh();
  }

  void scheduleRefresh() {
    timer?.cancel();
    final now = DateTime.now();
    timer =
        Timer(DateTime(now.year, now.month, now.day + 1).difference(now), () {
      if (!mounted) return;
      setState(() => today = DateTime.now());
      scheduleRefresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => today = DateTime.now());
      scheduleRefresh();
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
    final reference = dailyVerseReference(today);
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
