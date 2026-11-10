import 'package:flutter_test/flutter_test.dart';
import 'package:selah/features/reader/reader_scroll_intent.dart';

void main() {
  test('Small corrections do not reveal menus, deliberate upward scroll does',
      () {
    final intent = ReaderScrollIntent();
    expect(intent.update(-10, 400, visible: false), isNull);
    expect(intent.update(-20, 380, visible: false), isNull);
    expect(intent.update(-50, 330, visible: false), isTrue);
  });
  test('Reversals and separate gestures do not accumulate toward showing menus',
      () {
    final intent = ReaderScrollIntent();
    expect(intent.update(-60, 400, visible: false), isNull);
    expect(intent.update(5, 405, visible: false), isNull);
    expect(intent.update(-30, 375, visible: false), isNull);
    intent.reset();
    expect(intent.update(-60, 315, visible: false), isNull);
  });
  test('Menus stay visible for small downward gestures, hide after threshold',
      () {
    final intent = ReaderScrollIntent();
    expect(intent.update(20, 100, visible: true), isNull);
    expect(intent.update(28, 128, visible: true), isFalse);
  });
  test('Reaching the chapter top always restores menus', () {
    expect(ReaderScrollIntent().update(-1, 0, visible: false), isTrue);
  });
}
