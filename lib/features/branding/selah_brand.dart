import 'package:flutter/material.dart';

/// Original SELAH mark: an open book beneath the morning sun.
class SelahBrand extends StatelessWidget {
  const SelahBrand({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
      label: 'SELAH. Pause. Reflect. Grow.',
      child: ExcludeSemantics(
          child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(
                    width: 38,
                    height: 38,
                    child: CustomPaint(painter: _SelahMarkPainter())),
                const SizedBox(width: 12),
                Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('SELAH',
                          style: TextStyle(
                              fontFamily: 'SourceSerif4',
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 3,
                              height: 1.1,
                              color: Theme.of(context).colorScheme.onSurface)),
                      const SizedBox(height: 3),
                      Text('Pause. Reflect. Grow.',
                          style: TextStyle(
                              fontSize: 9,
                              letterSpacing: .6,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                    ]),
              ]))));
}

class _SelahMarkPainter extends CustomPainter {
  const _SelahMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 64, size.height / 64);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, 0, 64, 64), const Radius.circular(16)),
        Paint()..color = const Color(0xff244b3e));
    final gold = Paint()..color = const Color(0xffd8bb79);
    canvas.drawCircle(const Offset(32, 21), 5, gold);
    gold
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final ray in [
      [const Offset(32, 10), const Offset(32, 12)],
      [const Offset(21, 14), const Offset(23, 16)],
      [const Offset(43, 14), const Offset(41, 16)],
    ]) {
      canvas.drawLine(ray[0], ray[1], gold);
    }
    final book = Path()
      ..moveTo(32, 34)
      ..cubicTo(26, 29, 20, 27, 13, 29)
      ..lineTo(13, 48)
      ..cubicTo(20, 46, 26, 48, 32, 53)
      ..cubicTo(38, 48, 44, 46, 51, 48)
      ..lineTo(51, 29)
      ..cubicTo(44, 27, 38, 29, 32, 34)
      ..lineTo(32, 53);
    canvas.drawPath(
        book,
        Paint()
          ..color = const Color(0xfffaf7ef)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
