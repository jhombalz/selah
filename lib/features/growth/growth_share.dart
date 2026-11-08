import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/bible.dart';
import '../../data/growth_entry.dart';

Future<void> previewGrowthShare(
    BuildContext context, Bible bible, GrowthEntry entry) async {
  bool scripture = entry.reference != null,
      reflection = false,
      prayer = false,
      action = false;
  String payload() {
    final pieces = <String>[];
    if (scripture && entry.reference != null) {
      final reference = entry.reference!;
      pieces.add(
          '${bible.verse(reference).text}\n${bible.reference(reference)} · ${bible.abbreviation}');
      if (bible.licenseText.isNotEmpty) {
        pieces.add(bible.licenseText);
      } else if (bible.id == 'cebocb') {
        pieces.add(
            'Biblica® Open Ang Pulong sa Dios™ · © 2009, 2010, 2014, 2024 Biblica, Inc. · CC BY-SA 4.0\nhttps://ebible.org/cebocb/copyright.htm');
      }
    }
    if (reflection && entry.reflection.isNotEmpty) {
      pieces.add('My reflection\n${entry.reflection}');
    }
    if (prayer && entry.prayer.isNotEmpty) {
      pieces.add('My prayer\n${entry.prayer}');
    }
    if (action && entry.action.isNotEmpty) {
      pieces.add('My response\n${entry.action}');
    }
    if (pieces.isNotEmpty) {
      pieces.add('Shared from SELAH · Pause. Reflect. Grow.');
    }
    return pieces.join('\n\n');
  }

  await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, update) {
            final text = payload();
            return AlertDialog(
                title: const Text('Choose what to share'),
                content: SizedBox(
                    width: 520,
                    child: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text(
                          'Only the checked content below will be shared. Private writing is unchecked by default.'),
                      if (entry.reference != null)
                        CheckboxListTile(
                            title: const Text('Scripture and attribution'),
                            value: scripture,
                            onChanged: (v) => update(() => scripture = v!)),
                      if (entry.reflection.isNotEmpty)
                        CheckboxListTile(
                            title: const Text('My reflection'),
                            value: reflection,
                            onChanged: (v) => update(() => reflection = v!)),
                      if (entry.prayer.isNotEmpty)
                        CheckboxListTile(
                            title: const Text('My prayer'),
                            value: prayer,
                            onChanged: (v) => update(() => prayer = v!)),
                      if (entry.action.isNotEmpty)
                        CheckboxListTile(
                            title: const Text('My response'),
                            value: action,
                            onChanged: (v) => update(() => action = v!)),
                      const Divider(),
                      const Text('PREVIEW',
                          style: TextStyle(fontSize: 11, letterSpacing: 2)),
                      const SizedBox(height: 12),
                      SelectableText(
                          text.isEmpty ? 'Choose content to preview.' : text),
                    ]))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: text.isEmpty
                          ? null
                          : () async {
                              await Clipboard.setData(
                                  ClipboardData(text: text));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Selected content copied.')));
                              }
                            },
                      child: const Text('Copy')),
                  FilledButton(
                      onPressed: text.isEmpty
                          ? null
                          : () async {
                              try {
                                final box =
                                    context.findRenderObject() as RenderBox?;
                                await SharePlus.instance.share(ShareParams(
                                    text: text,
                                    sharePositionOrigin: box == null
                                        ? null
                                        : box.localToGlobal(Offset.zero) &
                                            box.size));
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Sharing is unavailable here. You can use Copy.')));
                                }
                              }
                            },
                      child: const Text('Share'))
                ]);
          }));
}
