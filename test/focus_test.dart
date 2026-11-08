import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/features/focus/focus_controller.dart';
import 'package:selah/features/focus/focus_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('selah/focus-test');
  late Map<String, dynamic> state;
  late List<MethodCall> calls;
  late FocusController controller;

  setUp(() {
    state = {
      'goalMinutes': 10,
      'selectedPackages': ['social.app']
    };
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'status':
          return state;
        case 'configure':
          state.addAll(Map<String, dynamic>.from(call.arguments as Map));
        case 'consent':
          state['consented'] = true;
        case 'apps':
          return [
            {'packageName': 'social.app', 'name': 'Social'},
            {'packageName': 'video.app', 'name': 'Video'},
          ];
      }
      return null;
    });
    controller = FocusController(channel: channel, supported: true);
  });
  tearDown(() {
    controller.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('changing goal preserves selected apps', (tester) async {
    await controller.refresh();
    await tester.pumpWidget(
        MaterialApp(home: FocusPage(controller: controller, onRead: () {})));
    await tester.tap(find.text('5 min'));
    await tester.pumpAndSettle();
    expect(controller.status.goalMinutes, 5);
    expect(controller.status.selectedPackages, {'social.app'});
  });

  testWidgets('declining disclosure never enables accessibility blocking',
      (tester) async {
    await controller.refresh();
    await tester.pumpWidget(
        MaterialApp(home: FocusPage(controller: controller, onRead: () {})));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Allow app blocking?'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(
        calls.where((call) => ['consent', 'enable', 'accessibilitySettings']
            .contains(call.method)),
        isEmpty);
  });

  testWidgets('app picker returns chosen packages', (tester) async {
    await controller.refresh();
    Set<String>? selection;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => TextButton(
                  onPressed: () async {
                    selection = await Navigator.of(context).push<Set<String>>(
                        MaterialPageRoute(
                            builder: (_) =>
                                FocusAppPicker(controller: controller)));
                  },
                  child: const Text('Open picker'),
                ))));
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Video'));
    await tester.pump();
    await tester.tap(find.text('Save 2 apps'));
    await tester.pumpAndSettle();
    expect(selection, {'social.app', 'video.app'});
  });
}
