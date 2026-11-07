import 'package:flutter/material.dart';

class ChapterCompletionCard extends StatelessWidget {
  final bool completed;
  final bool saving;
  final String chapter;
  final VoidCallback onToggle;
  const ChapterCompletionCard(
      {super.key,
      required this.completed,
      required this.saving,
      required this.chapter,
      required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            border:
                Border.all(color: colors.outlineVariant.withValues(alpha: .5))),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: colors.primaryContainer, shape: BoxShape.circle),
                child: Icon(
                    completed ? Icons.check_rounded : Icons.menu_book_rounded,
                    color: colors.onPrimaryContainer,
                    size: 24)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(completed ? 'Chapter completed' : 'A moment well spent.',
                      style: const TextStyle(
                          fontFamily: 'SourceSerif4', fontSize: 23)),
                  const SizedBox(height: 6),
                  Text(
                      completed
                          ? '$chapter is part of your reading journey.'
                          : 'Finished $chapter? Save your progress when you’re ready.',
                      style: TextStyle(
                          color: colors.onSurfaceVariant, height: 1.5)),
                ])),
          ]),
          const SizedBox(height: 20),
          FilledButton.icon(
              key: const ValueKey('chapter-completion-action'),
              style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  backgroundColor:
                      completed ? colors.secondaryContainer : colors.primary,
                  foregroundColor: completed
                      ? colors.onSecondaryContainer
                      : colors.onPrimary),
              onPressed: saving ? null : onToggle,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(completed ? Icons.undo_rounded : Icons.check_rounded,
                      size: 20),
              label: Text(saving
                  ? 'Saving progress…'
                  : completed
                      ? 'Mark as unread'
                      : 'Mark as read')),
        ]));
  }
}
