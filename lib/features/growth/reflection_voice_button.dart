import '../common/selah_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReflectionVoiceButton extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;
  const ReflectionVoiceButton(
      {super.key, required this.controller, required this.onChanged});
  static const channel = MethodChannel('selah/voice');
  @override
  State<ReflectionVoiceButton> createState() => _ReflectionVoiceButtonState();
}

class _ReflectionVoiceButtonState extends State<ReflectionVoiceButton> {
  bool busy = false;
  String language = 'en-PH';
  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> dictate() async {
    if (busy) return;
    final selected = await showDialog<String>(
        context: context,
        builder: (context) => SelahDialog(
              title: const Text('Speak your reflection'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Text(
                        'Your phone’s speech service may send audio online. Language and offline support depend on your device. You can review the text before adding it.')),
                for (final option in {
                  'en-PH': 'English',
                  'fil-PH': 'Filipino / Tagalog',
                  'ceb-PH': 'Cebuano (if supported)'
                }.entries)
                  SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, option.key),
                      child: Text(option.value)),
                SimpleDialogOption(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
              ]),
            ));
    if (!mounted || selected == null) return;
    language = selected;
    setState(() => busy = true);
    try {
      final text = await ReflectionVoiceButton.channel
          .invokeMethod<String>('recognize', {'language': language});
      if (!mounted || text == null) return;
      if (text.trim().isEmpty) {
        message(
            'No words were recognized. Please try again or type your reflection.');
        return;
      }
      final reviewed = await showDialog<String>(
          context: context, builder: (_) => _VoiceReview(text: text));
      if (!mounted || reviewed == null || reviewed.trim().isEmpty) return;
      final current = widget.controller.text;
      final combined =
          current.isEmpty ? reviewed.trim() : '$current\n${reviewed.trim()}';
      if (combined.length > 100000) {
        message(
            'Your reflection is too long to add more text. Please shorten it first.');
        return;
      }
      widget.controller.value = TextEditingValue(
          text: combined,
          selection: TextSelection.collapsed(offset: combined.length));
      widget.onChanged();
    } on PlatformException catch (error) {
      message(error.message ??
          'Voice input is unavailable. You can still type your reflection.');
    } on MissingPluginException {
      message(
          'Voice input needs the updated Android app. Keyboard dictation is also available.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const ValueKey('reflection-voice'),
          onPressed: busy ? null : dictate,
          icon: Icon(busy ? Icons.hourglass_top : Icons.mic_none_rounded),
          label: Text(busy ? 'Voice input open…' : 'Speak my reflection'),
        ));
  }
}

class _VoiceReview extends StatefulWidget {
  final String text;
  const _VoiceReview({required this.text});
  @override
  State<_VoiceReview> createState() => _VoiceReviewState();
}

class _VoiceReviewState extends State<_VoiceReview> {
  late final text = TextEditingController(text: widget.text);
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SelahDialog(
        title: const Text('Review your words'),
        content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
                child: TextField(
              key: const ValueKey('voice-review-text'),
              controller: text,
              minLines: 3,
              maxLines: 8,
              maxLength: 100000,
              decoration: const InputDecoration(
                  labelText: 'Recognized text',
                  helperText:
                      'This will be added after your existing reflection.',
                  helperMaxLines: 2),
            ))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Discard')),
          FilledButton(
              onPressed: () => Navigator.pop(context, text.text),
              child: const Text('Add to reflection')),
        ],
      );
}
