import 'dart:math';

class GrowthEntry {
  final String id, kind, translation;
  String title;
  final String? reference, cardId;
  final DateTime createdAt;
  DateTime updatedAt;
  String reflection, prayer, action, category, status, updateDraft;
  int step;
  bool completed, actionDone;
  final List<({DateTime date, String text})> updates;
  GrowthEntry(
      {required this.id,
      required this.kind,
      required this.title,
      required this.translation,
      this.reference,
      this.cardId,
      required this.createdAt,
      required this.updatedAt,
      this.reflection = '',
      this.prayer = '',
      this.action = '',
      this.category = 'Request',
      this.status = 'Still praying',
      this.updateDraft = '',
      this.step = 0,
      this.completed = false,
      this.actionDone = false,
      List<({DateTime date, String text})>? updates})
      : updates = updates ?? [];
  factory GrowthEntry.create(
      {required String kind,
      required String title,
      String translation = 'cebocb',
      String? reference,
      String? cardId}) {
    final now = DateTime.now().toUtc();
    return GrowthEntry(
        id: '${now.microsecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff)}',
        kind: kind,
        title: title,
        translation: translation,
        reference: reference,
        cardId: cardId,
        createdAt: now,
        updatedAt: now);
  }
  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'title': title,
        'translation': translation,
        'reference': reference,
        'cardId': cardId,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'reflection': reflection,
        'prayer': prayer,
        'action': action,
        'category': category,
        'status': status,
        'updateDraft': updateDraft,
        'step': step,
        'completed': completed,
        'actionDone': actionDone,
        'updates': [
          for (final update in updates)
            {'date': update.date.toUtc().toIso8601String(), 'text': update.text}
        ]
      };
  factory GrowthEntry.fromJson(Map<String, dynamic> row) {
    String text(String field, [int limit = 100000]) {
      final value = row[field];
      if (value is! String || value.length > limit) {
        throw FormatException('Invalid journal $field.');
      }
      return value;
    }

    DateTime date(Object? value) {
      final parsed = value is String && value.length <= 40
          ? DateTime.tryParse(value)
          : null;
      if (parsed == null || parsed.year < 1970 || parsed.year > 9999) {
        throw const FormatException('Invalid journal date.');
      }
      return parsed.toUtc();
    }

    final id = text('id', 80), kind = text('kind', 10);
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id) ||
        !['session', 'prayer'].contains(kind) ||
        row['step'] is! int ||
        (row['step'] as int) < 0 ||
        (row['step'] as int) > 4 ||
        row['completed'] is! bool ||
        row['actionDone'] is! bool ||
        (row['reference'] != null &&
            (row['reference'] is! String ||
                (row['reference'] as String).length > 32)) ||
        (row['cardId'] != null &&
            (row['cardId'] is! String ||
                (row['cardId'] as String).length > 80))) {
      throw const FormatException('Invalid journal entry.');
    }
    final category = text('category', 20), status = text('status', 20);
    if (!['Request', 'Gratitude', 'Lament', 'Waiting'].contains(category) ||
        !['Still praying', 'Answered', 'Archived'].contains(status)) {
      throw const FormatException('Invalid prayer status.');
    }
    final rawUpdates = row['updates'];
    if (rawUpdates is! List || rawUpdates.length > 1000) {
      throw const FormatException('Invalid prayer updates.');
    }
    final updates = <({DateTime date, String text})>[];
    for (final update in rawUpdates) {
      if (update is! Map<String, dynamic> ||
          update['text'] is! String ||
          (update['text'] as String).length > 100000) {
        throw const FormatException('Invalid prayer update.');
      }
      updates.add((date: date(update['date']), text: update['text'] as String));
    }
    return GrowthEntry(
        id: id,
        kind: kind,
        title: text('title', 200),
        translation: text('translation', 64),
        reference: row['reference'] as String?,
        cardId: row['cardId'] as String?,
        createdAt: date(row['createdAt']),
        updatedAt: date(row['updatedAt']),
        reflection: text('reflection'),
        updateDraft: row['updateDraft'] == null ? '' : text('updateDraft'),
        prayer: text('prayer'),
        action: text('action'),
        category: category,
        status: status,
        step: row['step'] as int,
        completed: row['completed'] as bool,
        actionDone: row['actionDone'] as bool,
        updates: updates);
  }
}
