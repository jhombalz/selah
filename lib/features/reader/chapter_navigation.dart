import 'package:flutter/material.dart';

class ChapterNavigationArrow extends StatelessWidget {
  final bool previous;
  final VoidCallback? onPressed;
  const ChapterNavigationArrow(
      {super.key, required this.previous, this.onPressed});
  @override
  Widget build(BuildContext context) => IconButton(
      tooltip: previous ? 'Previous chapter' : 'Next chapter',
      style: IconButton.styleFrom(
          minimumSize: const Size(52, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      onPressed: onPressed,
      icon:
          Icon(previous ? Icons.chevron_left : Icons.chevron_right, size: 30));
}

/// Shared chapter controls for bundled, downloaded and online translations.
class ChapterNavigation extends StatelessWidget {
  final String label;
  final VoidCallback? onPrevious, onNext, onPick;
  final bool controlsVisible;
  const ChapterNavigation(
      {super.key,
      required this.label,
      this.onPrevious,
      this.onNext,
      this.onPick,
      this.controlsVisible = true});
  @override
  Widget build(BuildContext context) => Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      elevation: controlsVisible ? 3 : 0,
      borderRadius: BorderRadius.circular(40),
      clipBehavior: Clip.antiAlias,
      child: Row(children: [
        ChapterNavigationArrow(previous: true, onPressed: onPrevious),
        Expanded(
            child: TextButton(
                key: const ValueKey('passage-picker'),
                style: TextButton.styleFrom(
                    minimumSize: const Size(0, 56),
                    foregroundColor: Theme.of(context).colorScheme.onSurface),
                onPressed: onPick,
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)))),
        ChapterNavigationArrow(previous: false, onPressed: onNext),
      ]));
}
