import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/data/scripture_range.dart';
import 'package:selah/features/reader/passage_selection_layer.dart';

void main() {
  test('Selections normalize direction and retain combined verse boundaries',
      () {
    expect(ScriptureRange.between('GEN.1.4', 'GEN.1.2'), 'GEN.1.2-4');
    expect(ScriptureRange.between('GEN.1.17-18', 'GEN.1.16'), 'GEN.1.16-18');
    expect(ScriptureRange.between('GEN.1.17-18', 'GEN.1.19'), 'GEN.1.17-19');
    expect(() => ScriptureRange.between('GEN.1.1', 'GEN.2.1'),
        throwsArgumentError);
    expect(() => ScriptureRange.parse('GEN.1.5-2'), throwsFormatException);
  });

  test('Partial recolor and removal preserve highlights outside the selection',
      () {
    final recolored =
        recolorPassage({'GEN.1.1-10': 1, 'JHN.3.16': 3}, 'GEN.1.3-4', 2);
    expect(recolored,
        {'GEN.1.1-2': 1, 'GEN.1.3-4': 2, 'GEN.1.5-10': 1, 'JHN.3.16': 3});
    expect(recolorPassage(recolored, 'GEN.1.2-6', null),
        {'GEN.1.1': 1, 'GEN.1.7-10': 1, 'JHN.3.16': 3});
  });

  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets('Long press and drag selects verses with ${kind.name}',
        (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final references = ['GEN.1.1', 'GEN.1.2', 'GEN.1.3'];
      final anchors = {
        for (final reference in references) reference: GlobalKey()
      };
      String? result;
      String? selected;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SizedBox(
        height: 400,
        child: PassageSelectionLayer(
            scrollController: scroll,
            references: references,
            anchors: anchors,
            onChanged: (value) => selected = value,
            onFinished: (value) => result = value,
            child: SingleChildScrollView(
                controller: scroll,
                child: Column(children: [
                  for (final reference in references)
                    SizedBox(
                        key: anchors[reference],
                        height: 120,
                        width: double.infinity,
                        child: InkWell(onTap: () {}, child: Text(reference))),
                ]))),
      ))));
      final start = tester.getCenter(find.byKey(anchors[references.last]!));
      final end = tester.getCenter(find.byKey(anchors[references.first]!));
      final gesture = await tester.startGesture(start, kind: kind);
      await tester.pump(const Duration(milliseconds: 600));
      expect(selected, 'GEN.1.3');
      await gesture.moveTo(end);
      await tester.pump();
      expect(selected, 'GEN.1.1-3');
      await gesture.up();
      await tester.pump();
      expect(result, 'GEN.1.1-3');
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Selection autoscroll extends beyond initially visible verses',
      (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final references = [for (int i = 1; i <= 12; i++) 'GEN.1.$i'];
    final anchors = {
      for (final reference in references) reference: GlobalKey()
    };
    String? result;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
      height: 350,
      child: PassageSelectionLayer(
          scrollController: scroll,
          references: references,
          anchors: anchors,
          onChanged: (_) {},
          onFinished: (value) => result = value,
          child: SingleChildScrollView(
              controller: scroll,
              child: Column(children: [
                for (final reference in references)
                  SizedBox(
                      key: anchors[reference],
                      height: 100,
                      width: double.infinity,
                      child: Text(reference)),
              ]))),
    ))));
    final gesture = await tester
        .startGesture(tester.getCenter(find.byKey(anchors['GEN.1.2']!)));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(const Offset(200, 345));
    await tester.pump(const Duration(milliseconds: 500));
    expect(scroll.offset, greaterThan(0));
    await gesture.up();
    await tester.pump();
    expect(ScriptureRange.parse(result!).end, greaterThan(4));
    await tester.pumpWidget(const SizedBox());
  });
}
