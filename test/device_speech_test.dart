import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/features/audio/chapter_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_tts');
  test(
      'Word progress updates within speech; pause stops immediately and resumes at the paused word',
      () async {
    final spoken = <String>[];
    final firstSpeech = Completer<int>();
    var stops = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'stop') stops++;
      if (call.method == 'speak') {
        spoken.add(call.arguments as String);
        if (spoken.length == 1) return firstSpeech.future;
      }
      return 1;
    });
    final backend = DeviceSpeechBackend();
    final signals = <AudioSignal>[];
    final subscription = backend.signals.listen(signals.add);
    try {
      const text = 'First second third fourth';
      await backend.load(Uri.dataFromString(text));
      final firstRun = backend.play();
      await Future<void>.delayed(Duration.zero);
      backend.tts.progressHandler!(text, 6, 12, 'second');
      await Future<void>.delayed(Duration.zero);
      expect(signals.last.position, const Duration(milliseconds: 6));
      expect(signals.last.progressOnly, isTrue);
      await backend.pause();
      expect(stops, 1);
      backend.tts.progressHandler!(text, 13, 18, 'third');
      firstSpeech.complete(0);
      await firstRun;
      expect(signals.any((s) => s.completed), isFalse);
      await backend.play();
      expect(spoken, [text, 'second third fourth']);
    } finally {
      await subscription.cancel();
      await backend.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });
  test(
      'Filipino speech falls back to Tagalog locale without changing the words',
      () async {
    final languages = <String>[];
    final spoken = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'setLanguage') {
        languages.add(call.arguments as String);
        return call.arguments == 'fil-PH' ? 0 : 1;
      }
      if (call.method == 'speak') spoken.add(call.arguments as String);
      return 1;
    });
    final backend = DeviceSpeechBackend();
    try {
      const text = 'Sa sinugdan gibuhat sa Dios ang langit ug ang yuta.';
      await backend.load(Uri.dataFromString(text,
          encoding: utf8,
          mimeType: 'text/plain',
          parameters: {'language': 'fil-PH'}));
      await backend.play();
      expect(languages, ['fil-PH', 'tl-PH']);
      expect(spoken, [text]);
    } finally {
      await backend.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });
}
