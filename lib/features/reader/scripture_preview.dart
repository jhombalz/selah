import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/bible.dart';

/// Resolve the selected edition before displaying or sharing its wording.
class ScripturePreview extends StatefulWidget {
  final String reference, translationId;
  final Future<Bible> Function(String) resolve;
  final TextStyle? style;
  const ScripturePreview(
      {super.key,
      required this.reference,
      required this.translationId,
      required this.resolve,
      this.style});
  @override
  State<ScripturePreview> createState() => _ScripturePreviewState();
}

class _ScripturePreviewState extends State<ScripturePreview>
    with WidgetsBindingObserver {
  late Future<Bible> pending = widget.resolve(widget.reference);
  Timer? expiryCheck;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    expiryCheck = Timer.periodic(const Duration(minutes: 1), (_) => reload());
  }

  void reload() {
    if (mounted) setState(() => pending = widget.resolve(widget.reference));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) reload();
  }

  @override
  void dispose() {
    expiryCheck?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ScripturePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reference != widget.reference ||
        oldWidget.translationId != widget.translationId) {
      pending = widget.resolve(widget.reference);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Bible>(
      future: pending,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Loading selected translation…'));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'This passage is unavailable. Connect to the internet to load this translation.'),
                TextButton(
                    onPressed: () => setState(
                        () => pending = widget.resolve(widget.reference)),
                    child: const Text('Retry passage')),
              ]);
        }
        final bible = snapshot.data!;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(bible.verse(widget.reference).text, style: widget.style),
          if (bible.licenseText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(bible.licenseText, style: const TextStyle(fontSize: 11)),
          ],
        ]);
      });
}
