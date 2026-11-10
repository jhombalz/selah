import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/user_database.dart';
import 'assessment_catalog.dart';
import 'assessment_store.dart';

class AssessmentPage extends StatefulWidget {
  final UserDatabase database;
  const AssessmentPage({super.key, required this.database});
  @override
  State<AssessmentPage> createState() => _AssessmentPageState();
}

class _AssessmentPageState extends State<AssessmentPage>
    with WidgetsBindingObserver {
  final clock = AssessmentClock();
  late final store = AssessmentStore(widget.database, clock: clock.now);
  List<AssessmentAttempt> attempts = [];
  String? openId, error;
  bool busy = true, confirming = false;
  Timer? timer;
  AssessmentAttempt? get opened {
    for (final a in attempts) {
      if (a.id == openId) return a;
    }
    return null;
  }

  AssessmentAttempt? get active {
    for (final a in attempts) {
      if (!a.submitted) return a;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(run(() async {}));
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || busy) return;
      final a = active;
      if (a != null && !clock.now().isBefore(a.deadline)) {
        unawaited(run(() async {}));
      } else {
        setState(() {});
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !busy) {
      unawaited(run(() async {}));
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    clock.elapsed.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> reload() async {
    final data = await store.load();
    if (mounted) {
      setState(() {
        attempts = data;
        busy = false;
      });
    }
  }

  Future<void> run(Future<void> Function() work) async {
    if (!mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await work();
      await reload();
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error =
              'Your assessment could not be saved. Please retry. The timer continues.';
        });
      }
    }
  }

  String duration(Duration value) {
    final seconds = value.inSeconds.clamp(0, 999999);
    return '${(seconds ~/ 3600).toString().padLeft(2, '0')}:${((seconds % 3600) ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  String localTime(DateTime date) =>
      '${MaterialLocalizations.of(context).formatMediumDate(date.toLocal())}, ${TimeOfDay.fromDateTime(date.toLocal()).format(context)}';
  Future<void> start(int level) async {
    if (busy || confirming) return;
    confirming = true;
    final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('The timer cannot be paused'),
              content: SingleChildScrollView(
                  child: Text(
                      'Level $level · ${assessmentNames[level - 1]}\n20 questions · ${assessmentMinutes[level - 1]} minutes\n\n'
                      'Once you start, the timer keeps running when you leave this screen, switch apps, or close SELAH. Your answers are saved as you go. Time expiry automatically submits your saved answers; unanswered questions count as incorrect.\n\n'
                      'You need 80% (16/20) to pass. Correct answers will not be shown. A retake becomes available 24 hours after submission.\n\nStart only when you are ready.')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Not now')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Start timed assessment'))
              ],
            ));
    confirming = false;
    if (!mounted || accepted != true) return;
    await run(() async {
      final a = await store.start(level);
      openId = a.id;
    });
  }

  Future<void> submit(AssessmentAttempt a) async {
    if (busy || confirming) return;
    confirming = true;
    final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Submit assessment?'),
              content: Text(
                  '${a.answers.length} of 20 answered. ${20 - a.answers.length} unanswered.\n\n'
                  'Your choices cannot be changed after submission. Unanswered questions count as incorrect. The 24-hour retake wait starts when submitted.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep reviewing')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Submit'))
              ],
            ));
    confirming = false;
    if (mounted && accepted == true) await run(() => store.submit(a.id));
  }

  Widget hub() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Grow in understanding',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        const Text(
            'Five English assessments · 20 questions each · 80% to pass.\nYour score measures knowledge of this question set, not your faith or closeness to God.'),
        const SizedBox(height: 16),
        if (active case final a?)
          Card(
              child: ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: Text('Continue Level ${a.level}'),
                  subtitle: Text(
                      '${a.answers.length}/20 answered · ${duration(a.deadline.difference(clock.now()))} remaining'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: busy ? null : () => setState(() => openId = a.id))),
        for (var level = 1; level <= 5; level++) levelCard(level),
        const SizedBox(height: 16),
        const Text(
            'Progress and retake limits are stored on this installation and are not included in Bible backups. Offline timing is not tamper-proof across device-clock changes or cleared app data.',
            style: TextStyle(fontSize: 12)),
        if (attempts.any((a) => a.submitted)) ...[
          const SizedBox(height: 24),
          Text('Previous submissions',
              style: Theme.of(context).textTheme.titleLarge),
          for (final a in attempts.where((a) => a.submitted).take(20))
            ListTile(
                title: Text(
                    'Level ${a.level} · ${a.score}/20 · ${a.percent}% · ${a.passed ? 'Passed' : 'Failed'}'),
                subtitle: Text(localTime(a.submittedAt!)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => setState(() => openId = a.id)),
        ],
      ]);
  Widget levelCard(int level) {
    final unlocked = AssessmentStore.unlocked(level, attempts);
    final retry = AssessmentStore.retryAt(level, attempts);
    final waiting = retry != null && clock.now().isBefore(retry);
    final passed = attempts.any((a) => a.level == level && a.passed);
    final available = unlocked && !waiting && active == null && !busy;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(!unlocked
                      ? Icons.lock_outline
                      : passed
                          ? Icons.check_circle_outline
                          : Icons.quiz_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(
                          'Level $level · ${assessmentNames[level - 1]}',
                          style: Theme.of(context).textTheme.titleMedium))
                ]),
                const SizedBox(height: 8),
                Text('20 questions · ${assessmentMinutes[level - 1]} minutes'),
                const SizedBox(height: 8),
                Text(!unlocked
                    ? 'Pass Level ${level - 1} to unlock.'
                    : waiting
                        ? 'Retake available ${localTime(retry)}'
                        : passed
                            ? 'Passed · You may practice again when ready.'
                            : 'Score at least 16/20 to pass.'),
                const SizedBox(height: 12),
                FilledButton.tonal(
                    onPressed: available ? () => start(level) : null,
                    child: Text(waiting
                        ? 'Waiting for retake'
                        : !unlocked
                            ? 'Locked'
                            : 'Start Level $level')),
              ],
            )));
  }

  Widget exam(AssessmentAttempt a) {
    final questionId = a.order[a.current];
    final q = assessmentBank[a.level - 1][questionId];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Text(
                    'Time remaining · ${duration(a.deadline.difference(clock.now()))}',
                    style: Theme.of(context).textTheme.titleLarge),
                const Text('The timer cannot be paused.'),
                Text(
                    '${a.answers.length}/20 answered · ${a.flagged.length} flagged'),
              ]))),
      const SizedBox(height: 16),
      Text('Question ${a.current + 1} of 20 · ${q.topic}',
          style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 12),
      Text(q.prompt, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      for (final choice in a.options(questionId))
        Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.all(18),
                    backgroundColor: a.answers[questionId] == choice
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null),
                onPressed: busy
                    ? null
                    : () => run(() => store.answer(a.id, questionId, choice)),
                child: Row(children: [
                  Icon(a.answers[questionId] == choice
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked),
                  const SizedBox(width: 12),
                  Expanded(child: Text(q.choices[choice]))
                ]))),
      TextButton.icon(
          onPressed: busy
              ? null
              : () => run(() => store.answer(a.id, questionId, null,
                  flag: !a.flagged.contains(questionId))),
          icon: Icon(a.flagged.contains(questionId)
              ? Icons.flag
              : Icons.outlined_flag),
          label: const Text('Flag for review')),
      const SizedBox(height: 12),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (var index = 0; index < 20; index++)
          SizedBox(
              width: 48,
              height: 48,
              child: Tooltip(
                  message:
                      'Question ${index + 1}${a.flagged.contains(a.order[index]) ? ', flagged' : ''}${a.answers.containsKey(a.order[index]) ? ', answered' : ', unanswered'}',
                  child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: index == a.current
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null),
                      onPressed: busy
                          ? null
                          : () => run(() => store.answer(a.id, questionId, null,
                              current: index)),
                      child: Text(
                          '${index + 1}${a.flagged.contains(a.order[index]) ? '*' : a.answers.containsKey(a.order[index]) ? '•' : ''}'))))
      ]),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(
            child: OutlinedButton(
                onPressed: busy || a.current == 0
                    ? null
                    : () => run(() => store.answer(a.id, questionId, null,
                        current: a.current - 1)),
                child: const Text('Previous'))),
        const SizedBox(width: 12),
        Expanded(
            child: FilledButton(
                onPressed: busy
                    ? null
                    : a.current == 19
                        ? () => submit(a)
                        : () => run(() => store.answer(a.id, questionId, null,
                            current: a.current + 1)),
                child: Text(a.current == 19 ? 'Review & submit' : 'Next')))
      ]),
      const SizedBox(height: 12),
      TextButton(
          onPressed: busy ? null : () => submit(a),
          child: const Text('Submit assessment')),
    ]);
  }

  Widget result(AssessmentAttempt a) {
    final topics = assessmentBank[a.level - 1].map((q) => q.topic).toSet();
    final retry = AssessmentStore.retryAt(a.level, attempts)!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Icon(a.passed ? Icons.check_circle_outline : Icons.school_outlined,
          size: 64, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 16),
      Text(a.passed ? 'Passed' : 'Failed',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge),
      Text('${a.score}/20 · ${a.percent}%',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 16),
      Text(
          'Level ${a.level} · ${assessmentNames[a.level - 1]}\nSubmitted ${localTime(a.submittedAt!)}\nPass mark: 80% (16/20)'),
      const SizedBox(height: 12),
      Text(a.passed
          ? a.level == 5
              ? 'You have completed all five levels. Keep reading and growing in understanding.'
              : 'Level ${a.level + 1} is now unlocked.'
          : 'Take time to revisit Scripture and reflect. This grade is not a measure of your faith.'),
      const SizedBox(height: 20),
      Text('By topic', style: Theme.of(context).textTheme.titleLarge),
      for (final topic in topics)
        Builder(builder: (_) {
          final ids = List.generate(20, (i) => i)
              .where((i) => assessmentBank[a.level - 1][i].topic == topic);
          final score = ids.where((i) => a.answers[i] == 0).length;
          return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(topic),
              trailing: Text('$score/${ids.length}'));
        }),
      const Text(
          'Correct choices and individual-question results are not shown.'),
      const SizedBox(height: 16),
      Text(clock.now().isBefore(retry)
          ? 'Retake available ${localTime(retry)}'
          : 'A retake is now available.'),
      const SizedBox(height: 16),
      FilledButton(
          onPressed: () => setState(() => openId = null),
          child: const Text('Back to levels')),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final a = opened;
    return PopScope(
        canPop: openId == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && mounted) setState(() => openId = null);
        },
        child: Scaffold(
          appBar: AppBar(
              title: Text(a == null
                  ? 'Bible assessments'
                  : 'Level ${a.level} · ${a.submitted ? 'Results' : 'Assessment'}'),
              leading: a == null
                  ? null
                  : IconButton(
                      tooltip: 'Back to levels · timer continues',
                      icon: const Icon(Icons.arrow_back),
                      onPressed:
                          busy ? null : () => setState(() => openId = null))),
          body: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    key: ValueKey('${a?.id}:${a?.submitted}:${a?.current}'),
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (busy) const LinearProgressIndicator(),
                      if (error != null)
                        Card(
                            child: ListTile(
                                title: Text(error!),
                                trailing: TextButton(
                                    onPressed:
                                        busy ? null : () => run(() async {}),
                                    child: const Text('Retry')))),
                      if (a == null)
                        hub()
                      else if (a.submitted)
                        result(a)
                      else
                        exam(a),
                    ],
                  ))),
        ));
  }
}
