import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/features/audio/chapter_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_tts');
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
