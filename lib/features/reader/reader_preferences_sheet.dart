import 'package:flutter/material.dart';

class ReaderPreferencesSheet extends StatefulWidget {
  final double fontSize;
  final bool paragraphs, redLetters;
  final void Function(double, bool) onSize;
  final ValueChanged<bool> onParagraphs, onRedLetters;
  final bool showFormatting;
  final List<Widget> extraActions;
  const ReaderPreferencesSheet(
      {super.key,
      required this.fontSize,
      required this.paragraphs,
      required this.redLetters,
      required this.onSize,
      required this.onParagraphs,
      required this.onRedLetters,
      this.showFormatting = true,
      this.extraActions = const []});
  @override
  State<ReaderPreferencesSheet> createState() => _ReaderPreferencesSheetState();
}

class _ReaderPreferencesSheetState extends State<ReaderPreferencesSheet> {
  late double size = widget.fontSize;
  late bool paragraphs = widget.paragraphs, red = widget.redLetters;
  void change(double value, {bool persist = true}) {
    setState(() => size = value.clamp(16, 32));
    widget.onSize(size, persist);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 12, 12),
            child: Row(children: [
              Expanded(
                  child: Text('Reading preferences',
                      style: Theme.of(context).textTheme.titleLarge)),
              IconButton(
                  tooltip: 'Close text size',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded)),
            ])),
        Flexible(
            child: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const SizedBox(height: 8),
                      Row(children: [
                        IconButton(
                            tooltip: 'Smaller text',
                            onPressed:
                                size <= 16 ? null : () => change(size - 1),
                            icon: const Icon(Icons.text_decrease)),
                        Expanded(
                            child: Slider(
                                label: '${size.round()}',
                                value: size,
                                min: 16,
                                max: 32,
                                divisions: 16,
                                onChanged: (value) =>
                                    change(value, persist: false),
                                onChangeEnd: (value) => change(value))),
                        IconButton(
                            tooltip: 'Larger text',
                            onPressed:
                                size >= 32 ? null : () => change(size + 1),
                            icon: const Icon(Icons.text_increase)),
                      ]),
                      Text('${size.round()} pt',
                          style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 20),
                      Text('Pause. Reflect. Grow.',
                          style: TextStyle(
                              fontFamily: 'SourceSerif4',
                              fontSize: size,
                              height: 1.6)),
                      const SizedBox(height: 16),
                      if (widget.showFormatting)
                        SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Paragraph reading'),
                            subtitle: const Text(
                                'Flowing text with verse numbers. Long-press and drag to select verses.'),
                            value: paragraphs,
                            onChanged: (value) {
                              setState(() => paragraphs = value);
                              widget.onParagraphs(value);
                            }),
                      if (widget.showFormatting)
                        SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Words of Jesus in red'),
                            subtitle: const Text(
                                'Only where this edition provides verified markers, currently KJV.'),
                            value: red,
                            onChanged: (value) {
                              setState(() => red = value);
                              widget.onRedLetters(value);
                            }),
                      ...widget.extraActions,
                    ])))),
      ]));
}
