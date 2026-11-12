import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/bible.dart';
import '../../data/growth_entry.dart';

Future<void> previewGrowthShare(
    BuildContext context, Bible bible, GrowthEntry entry,
    {Future<Bible> Function(String)? resolve}) async {
  if (resolve != null && entry.reference != null) {
    try {
      bible = await resolve(entry.reference!);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'The selected translation could not be loaded. Connect and try sharing again.')));
      }
      return;
    }
    if (!context.mounted) return;
  }
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

  await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => StatefulBuilder(builder: (context, update) {
            final text = payload();
            final colors = Theme.of(context).colorScheme;
            return SafeArea(
                top: false,
                child: SizedBox(
                    height: MediaQuery.sizeOf(context).height * .84,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                              padding: const EdgeInsets.fromLTRB(24, 0, 12, 16),
                              child: Row(children: [
                                Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                        color: colors.primaryContainer,
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    child: Icon(Icons.ios_share_rounded,
                                        color: colors.primary)),
                                const SizedBox(width: 14),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text('Share a little light',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                  fontFamily: 'SourceSerif4')),
                                      const Text('Choose what to share',
                                          style: TextStyle(fontSize: 12)),
                                    ])),
                                IconButton(
                                    tooltip: 'Close share preview',
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(Icons.close_rounded)),
                              ])),
                          const Divider(height: 1),
                          Flexible(
                              child: SizedBox(
                                  width: double.infinity,
                                  child: SingleChildScrollView(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                                padding:
                                                    const EdgeInsets.all(14),
                                                decoration: BoxDecoration(
                                                    color: colors
                                                        .surfaceContainerLow,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16)),
                                                child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Icon(
                                                          Icons
                                                              .lock_outline_rounded,
                                                          size: 20,
                                                          color:
                                                              colors.primary),
                                                      const SizedBox(width: 10),
                                                      const Expanded(
                                                          child: Text(
                                                              'Only the checked content below will be shared. Private writing is unchecked by default.')),
                                                    ])),
                                            const SizedBox(height: 12),
                                            if (entry.reference != null)
                                              CheckboxListTile(
                                                  title: const Text(
                                                      'Scripture and attribution'),
                                                  value: scripture,
                                                  onChanged: (v) => update(
                                                      () => scripture = v!)),
                                            if (entry.reflection.isNotEmpty)
                                              CheckboxListTile(
                                                  title: const Text(
                                                      'My reflection'),
                                                  value: reflection,
                                                  onChanged: (v) => update(
                                                      () => reflection = v!)),
                                            if (entry.prayer.isNotEmpty)
                                              CheckboxListTile(
                                                  title:
                                                      const Text('My prayer'),
                                                  value: prayer,
                                                  onChanged: (v) => update(
                                                      () => prayer = v!)),
                                            if (entry.action.isNotEmpty)
                                              CheckboxListTile(
                                                  title:
                                                      const Text('My response'),
                                                  value: action,
                                                  onChanged: (v) => update(
                                                      () => action = v!)),
                                            const SizedBox(height: 16),
                                            Container(
                                                width: double.infinity,
                                                padding:
                                                    const EdgeInsets.all(20),
                                                decoration: BoxDecoration(
                                                    color: colors
                                                        .surfaceContainerLow,
                                                    border: Border.all(
                                                        color: colors
                                                            .outlineVariant),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20)),
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text('YOUR SHARE PREVIEW',
                                                          style: TextStyle(
                                                              fontSize: 11,
                                                              letterSpacing:
                                                                  1.8,
                                                              color: colors
                                                                  .primary)),
                                                      const SizedBox(
                                                          height: 14),
                                                      SelectableText(
                                                          text.isEmpty
                                                              ? 'Choose content to preview.'
                                                              : text,
                                                          style: const TextStyle(
                                                              fontFamily:
                                                                  'SourceSerif4',
                                                              fontSize: 16,
                                                              height: 1.55)),
                                                    ])),
                                          ])))),
                          Container(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 12),
                              decoration: BoxDecoration(
                                  border: Border(
                                      top: BorderSide(
                                          color: colors.outlineVariant))),
                              child: Row(children: [
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
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                      content: Text(
                                                          'Selected content copied.')));
                                            }
                                          },
                                    child: const Text('Copy')),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: FilledButton.icon(
                                        icon: const Icon(
                                            Icons.ios_share_rounded,
                                            size: 18),
                                        onPressed: text.isEmpty
                                            ? null
                                            : () async {
                                                try {
                                                  final box =
                                                      context.findRenderObject()
                                                          as RenderBox?;
                                                  await SharePlus.instance
                                                      .share(ShareParams(
                                                          text: text,
                                                          sharePositionOrigin: box ==
                                                                  null
                                                              ? null
                                                              : box.localToGlobal(
                                                                      Offset
                                                                          .zero) &
                                                                  box.size));
                                                } catch (_) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                            const SnackBar(
                                                                content: Text(
                                                                    'Sharing is unavailable here. You can use Copy.')));
                                                  }
                                                }
                                              },
                                        label: const Text('Share'))),
                              ])),
                        ])));
          }));
}
