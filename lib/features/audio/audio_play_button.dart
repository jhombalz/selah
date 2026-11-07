import 'package:flutter/material.dart';

/// Compact player control alongside the chapter-navigation pill.
class AudioPlayButton extends StatelessWidget {
  final bool playing;
  final bool loading;
  final String label;
  final VoidCallback? onPressed;
  const AudioPlayButton(
      {super.key,
      required this.playing,
      required this.loading,
      required this.label,
      required this.onPressed});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: label,
        child: IconButton.filled(
          key: const ValueKey('chapter-audio'),
          style: IconButton.styleFrom(
            minimumSize: const Size(56, 56),
            shape: const CircleBorder(),
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: loading ? null : onPressed,
          icon: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 30),
        ),
      );
}
