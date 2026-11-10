import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/features/growth/reflection_voice_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final discard in [false, true]) {
    testWidgets(
        'Voice preview ${discard ? 'discards safely' : 'appends reviewed words'}',
        (tester) async {
      final controller = TextEditingController(text: 'My existing reflection.');
      addTearDown(controller.dispose);
      var saves = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ReflectionVoiceButton.channel,
              (call) async {
        expect(call.method, 'recognize');
        expect(call.arguments, {'language': 'fil-PH'});
        return 'Thank you God.';
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ReflectionVoiceButton.channel, null));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: ReflectionVoiceButton(
                  controller: controller, onChanged: () => saves++))));
      await tester.tap(find.text('Speak my reflection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filipino / Tagalog'));
      await tester.pumpAndSettle();
      expect(controller.text, 'My existing reflection.');
      expect(saves, 0);
      await tester.enterText(find.byKey(const ValueKey('voice-review-text')),
          'Thank You for today.');
      await tester.tap(find.text(discard ? 'Discard' : 'Add to reflection'));
      await tester.pumpAndSettle();
      expect(
          controller.text,
          discard
              ? 'My existing reflection.'
              : 'My existing reflection.\nThank You for today.');
      expect(saves, discard ? 0 : 1);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Recognition cancellation preserves writing', (tester) async {
    final controller = TextEditingController(text: 'Keep my writing');
    addTearDown(controller.dispose);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            ReflectionVoiceButton.channel, (_) async => null);
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ReflectionVoiceButton.channel, null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ReflectionVoiceButton(
                controller: controller,
                onChanged: () => fail('Cancelled dictation must not save')))));
    await tester.tap(find.text('Speak my reflection'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(controller.text, 'Keep my writing');
    expect(find.text('Review your words'), findsNothing);
  });
}
