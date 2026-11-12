import 'package:flutter/material.dart';

class ReaderToolbar extends StatelessWidget {
  final String chapter, abbreviation, translation;
  final VoidCallback onSearch,
      onBooks,
      onTranslation,
      onTextSize,
      onLayout,
      onAudio;
  final bool hasAudio, playing, loading;
  final String audioLabel;
  const ReaderToolbar(
      {super.key,
      required this.chapter,
      required this.abbreviation,
      required this.translation,
      required this.onSearch,
      required this.onBooks,
      required this.onTranslation,
      required this.onTextSize,
      required this.onLayout,
      required this.onAudio,
      required this.hasAudio,
      required this.playing,
      required this.loading,
      required this.audioLabel});

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final wide = MediaQuery.sizeOf(context).width >= 1000 &&
            constraints.maxWidth >= 800;
        final colors = Theme.of(context).colorScheme;
        return Row(key: const ValueKey('reader-toolbar'), children: [
          Expanded(
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: wide ? 430 : double.infinity),
                      child: Row(children: [
                        Expanded(
                            child: Material(
                                color: colors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(30),
                                child: InkWell(
                                    key: const ValueKey('reader-search'),
                                    borderRadius: BorderRadius.circular(30),
                                    onTap: onSearch,
                                    child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 12),
                                        child: Row(children: [
                                          Icon(Icons.search_rounded,
                                              size: 20,
                                              color: colors.onSurfaceVariant),
                                          const SizedBox(width: 8),
                                          Expanded(
                                              child: Text(chapter,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis))
                                        ]))))),
                        IconButton(
                            tooltip: 'Choose a book and chapter',
                            onPressed: onBooks,
                            icon:
                                const Icon(Icons.menu_book_outlined, size: 21)),
                      ])))),
          const SizedBox(width: 6),
          Tooltip(
              message: translation,
              child: OutlinedButton(
                  key: const ValueKey('translation-picker'),
                  onPressed: onTranslation,
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(52, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      side: BorderSide(color: colors.outlineVariant),
                      shape: const StadiumBorder()),
                  child: Text(abbreviation,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)))),
          if (wide && hasAudio)
            IconButton(
                key: const ValueKey('chapter-audio'),
                tooltip: audioLabel,
                onPressed: loading ? null : onAudio,
                icon: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.headphones_outlined,
                        size: 22)),
          if (wide)
            IconButton(
                tooltip: 'Reading layout',
                onPressed: onLayout,
                icon: const Icon(Icons.view_agenda_outlined, size: 21)),
          TextButton(
              key: const ValueKey('text-size'),
              onPressed: onTextSize,
              style: TextButton.styleFrom(
                  minimumSize: const Size(40, 40), padding: EdgeInsets.zero),
              child: const Text('AA',
                  style: TextStyle(fontWeight: FontWeight.w600))),
        ]);
      });
}
