import 'dart:convert';
import 'dart:math';
import 'dart:async';
import '../../data/user_database.dart';
import 'assessment_catalog.dart';

class AssessmentAttempt {
  final String id;
  final int level, seed;
  final DateTime startedAt, deadline;
  final List<int> order;
  final Map<int, int> answers;
  final Set<int> flagged;
  DateTime? submittedAt;
  int current;
  AssessmentAttempt(
      {required this.id,
      required this.level,
      required this.seed,
      required this.startedAt,
      required this.deadline,
      required this.order,
      Map<int, int>? answers,
      Set<int>? flagged,
      this.submittedAt,
      this.current = 0})
      : answers = answers ?? {},
        flagged = flagged ?? {};
  bool get submitted => submittedAt != null;
  int get score => answers.values.where((answer) => answer == 0).length;
  int get percent => score * 5;
  bool get passed => submitted && percent >= assessmentPassPercent;
  List<int> options(int question) =>
      [0, 1, 2, 3]..shuffle(Random(seed + question));
  Map<String, dynamic> toJson() => {
        'version': 1,
        'id': id,
        'level': level,
        'seed': seed,
        'startedAt': startedAt.toIso8601String(),
        'deadline': deadline.toIso8601String(),
        'order': order,
        'answers': {for (final e in answers.entries) '${e.key}': e.value},
        'flagged': flagged.toList(),
        'current': current,
        'submittedAt': submittedAt?.toIso8601String(),
      };
  factory AssessmentAttempt.fromJson(Map<String, dynamic> data) {
    final level = data['level'] as int;
    final order = (data['order'] as List).cast<int>();
    final answers = (data['answers'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(int.parse(k), v as int));
    final flags = (data['flagged'] as List).cast<int>().toSet();
    final current = data['current'] as int;
    if (data['version'] != 1 ||
        level < 1 ||
        level > 5 ||
        order.length != 20 ||
        order.toSet().length != 20 ||
        order.any((q) => q < 0 || q >= 20) ||
        answers.entries.any(
            (e) => e.key < 0 || e.key >= 20 || e.value < 0 || e.value > 3) ||
        flags.any((q) => q < 0 || q >= 20) ||
        current < 0 ||
        current >= 20) {
      throw const FormatException('Invalid assessment record.');
    }
    final start = DateTime.parse(data['startedAt'] as String).toUtc();
    final deadline = DateTime.parse(data['deadline'] as String).toUtc();
    if (deadline.difference(start).inMinutes != assessmentMinutes[level - 1]) {
      throw const FormatException('Invalid assessment deadline.');
    }
    return AssessmentAttempt(
        id: data['id'] as String,
        level: level,
        seed: data['seed'] as int,
        startedAt: start,
        deadline: deadline,
        order: order,
        answers: answers,
        flagged: flags,
        current: current,
        submittedAt: data['submittedAt'] == null
            ? null
            : DateTime.parse(data['submittedAt'] as String).toUtc());
  }
}

class AssessmentStore {
  static final changes = StreamController<void>.broadcast();
  final UserDatabase database;
  final DateTime Function() clock;
  AssessmentStore(this.database, {DateTime Function()? clock})
      : clock = clock ?? DateTime.now;
  Future<List<AssessmentAttempt>> _read() async => [
        for (final row in await database
            .customSelect(
                'SELECT content FROM assessment_attempts ORDER BY rowid DESC')
            .get())
          AssessmentAttempt.fromJson(
              jsonDecode(row.read<String>('content')) as Map<String, dynamic>)
      ];
  Future<void> _write(AssessmentAttempt attempt) async {
    await database.customStatement(
        'INSERT INTO assessment_attempts (id, content) VALUES (?, ?) ON CONFLICT(id) DO UPDATE SET content=excluded.content',
        [attempt.id, jsonEncode(attempt.toJson())]);
    changes.add(null);
  }

  Future<List<AssessmentAttempt>> load() => database.transaction(() async {
        final attempts = await _read();
        final now = clock().toUtc();
        for (final a in attempts
            .where((a) => !a.submitted && !now.isBefore(a.deadline))) {
          a.submittedAt = a.deadline;
          await _write(a);
        }
        return attempts;
      });
  static bool unlocked(int level, List<AssessmentAttempt> attempts) =>
      level == 1 || attempts.any((a) => a.level == level - 1 && a.passed);
  static DateTime? retryAt(int level, List<AssessmentAttempt> attempts) {
    final dates = attempts
        .where((a) => a.level == level && a.submitted)
        .map((a) => a.submittedAt!)
        .toList()
      ..sort();
    return dates.isEmpty ? null : dates.last.add(const Duration(hours: 24));
  }

  Future<AssessmentAttempt> start(int level) => database.transaction(() async {
        if (level < 1 || level > 5) {
          throw StateError('Unknown assessment level.');
        }
        final attempts = await load();
        if (attempts.any((a) => !a.submitted)) {
          throw StateError('Resume your current assessment first.');
        }
        if (!unlocked(level, attempts)) {
          throw StateError('Pass the previous level first.');
        }
        final now = clock().toUtc();
        final retry = retryAt(level, attempts);
        if (retry != null && now.isBefore(retry)) {
          throw StateError('Retakes open 24 hours after submission.');
        }
        final random = Random.secure();
        final a = AssessmentAttempt(
            id: '${now.microsecondsSinceEpoch}-${random.nextInt(1 << 30)}',
            level: level,
            seed: random.nextInt(1 << 30),
            startedAt: now,
            deadline: now.add(Duration(minutes: assessmentMinutes[level - 1])),
            order: List.generate(20, (i) => i)..shuffle(random));
        await _write(a);
        return a;
      });
  Future<void> answer(String id, int question, int? choice,
          {int? current, bool? flag}) =>
      database.transaction(() async {
        final attempts = await load();
        final a = attempts.firstWhere((a) => a.id == id);
        if (a.submitted) return;
        if (question < 0 ||
            question >= 20 ||
            (choice != null && (choice < 0 || choice > 3))) {
          throw StateError('Invalid choice.');
        }
        if (choice != null) a.answers[question] = choice;
        if (current != null && current >= 0 && current < 20) {
          a.current = current;
        }
        if (flag != null) {
          flag ? a.flagged.add(question) : a.flagged.remove(question);
        }
        await _write(a);
      });
  Future<void> submit(String id) => database.transaction(() async {
        final a = (await load()).firstWhere((a) => a.id == id);
        if (a.submitted) return;
        a.submittedAt = clock().toUtc();
        await _write(a);
      });
}

/// Uses elapsed time as well as wall time so changing the clock backwards while
/// the assessment screen is alive cannot give back time.
class AssessmentClock {
  final DateTime base = DateTime.now().toUtc();
  final Stopwatch elapsed = Stopwatch()..start();
  DateTime now() {
    final monotonic = base.add(elapsed.elapsed);
    final wall = DateTime.now().toUtc();
    return wall.isAfter(monotonic) ? wall : monotonic;
  }
}
