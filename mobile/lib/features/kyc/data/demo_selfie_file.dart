import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Creates a clearly illustrated, non-photographic selfie for demos.
///
/// This is intentionally generated at runtime so the demo fallback does not
/// ship or reuse a real person's biometric image.
abstract final class DemoSelfieFile {
  static Future<File> create() async {
    const width = 640;
    const height = 800;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final bounds = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());

    canvas.drawRect(
      bounds,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(width.toDouble(), height.toDouble()),
          const [Color(0xFF2A5F49), Color(0xFFB5DF68)],
        ),
    );

    final shoulderPaint = Paint()..color = const Color(0xFF173D31);
    canvas.drawOval(const Rect.fromLTWH(105, 515, 430, 320), shoulderPaint);

    final skinPaint = Paint()..color = const Color(0xFFE7A878);
    canvas.drawOval(const Rect.fromLTWH(188, 150, 264, 310), skinPaint);
    canvas.drawRect(const Rect.fromLTWH(274, 412, 92, 100), skinPaint);

    final hairPaint = Paint()..color = const Color(0xFF2A2523);
    final hair = Path()
      ..moveTo(184, 282)
      ..cubicTo(180, 125, 232, 78, 327, 92)
      ..cubicTo(430, 74, 486, 148, 452, 290)
      ..lineTo(418, 246)
      ..cubicTo(377, 208, 329, 194, 260, 218)
      ..lineTo(210, 302)
      ..close();
    canvas.drawPath(hair, hairPaint);

    final featurePaint = Paint()
      ..color = const Color(0xFF2A2523)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      const Offset(245, 304),
      const Offset(275, 304),
      featurePaint,
    );
    canvas.drawLine(
      const Offset(365, 304),
      const Offset(395, 304),
      featurePaint,
    );
    canvas.drawLine(
      const Offset(320, 314),
      const Offset(308, 360),
      featurePaint,
    );
    canvas.drawArc(
      const Rect.fromLTWH(278, 350, 84, 52),
      0.15,
      2.85,
      false,
      featurePaint,
    );

    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawOval(const Rect.fromLTWH(158, 115, 324, 390), guidePaint);

    final badge = RRect.fromRectAndRadius(
      const Rect.fromLTWH(208, 690, 224, 58),
      const Radius.circular(29),
    );
    canvas.drawRRect(
      badge,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    final badgeText = TextPainter(
      text: const TextSpan(
        text: 'DEMO SELFIE',
        style: TextStyle(
          color: Color(0xFF24513F),
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    badgeText.paint(canvas, Offset((width - badgeText.width) / 2, 708));

    final image = await recorder.endRecording().toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) {
      throw StateError('Could not create the demo selfie.');
    }

    final file = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}momoplus_demo_selfie.png',
    );
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return file;
  }
}
