import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/features/growth/growth_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Morning and bedtime use independent platform slots and chosen times',
      () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(GrowthReminders.channel, (call) async {
      calls.add(call);
      return true;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(GrowthReminders.channel, null));
    expect(await GrowthReminders.configure(true, 7, 30), isTrue);
    expect(
        await GrowthReminders.configure(true, 22, 15, slot: 'bedtime'), isTrue);
    expect(await GrowthReminders.configure(false, 7, 30), isTrue);
    expect(calls.map((c) => c.arguments), [
      {'enabled': true, 'hour': 7, 'minute': 30, 'slot': 'morning'},
      {'enabled': true, 'hour': 22, 'minute': 15, 'slot': 'bedtime'},
      {'enabled': false, 'hour': 7, 'minute': 30, 'slot': 'morning'},
    ]);
  });
}
