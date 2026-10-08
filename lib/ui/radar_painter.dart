import 'dart:math';
import 'package:flutter/material.dart';
import '../models/signal_device.dart';

class RadarPainter extends CustomPainter {
  final List<SignalDevice> devices;
  final double range;
  final double t; // 0..1 animation
  RadarPainter(this.devices, this.range, this.t);

  static int _hash(String s) {
    var h = 2166136261;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 16777619) & 0xFFFFFFFF;
    }
    return h;
  }

  static Offset blip(SignalDevice d, Offset c, double r, double range) {
    final frac = ((d.distance ?? range) / range).clamp(0.04, 1.0).toDouble();
    final a = (_hash(d.id) % 3600) / 3600 * 2 * pi;
    return c + Offset(cos(a), sin(a)) * (r * frac);
  }

  static SignalDevice? hitTest(List<SignalDevice> ds, Size size, double range, Offset p) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 10;
    SignalDevice? best;
    double bd = 30;
    for (final d in ds) {
      final dist = (blip(d, c, r, range) - p).distance;
      if (dist < bd) {
        bd = dist;
        best = d;
      }
    }
    return best;
  }

  void _label(Canvas canvas, String text, Offset o, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 120);
    tp.paint(canvas, o);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 10;
    final green = const Color(0xFF00E676);

    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF06140C));
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = green.withAlpha(90);
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(c, r * i / 4, ring);
      _label(canvas, '${(range * i / 4).round()} m', Offset(c.dx + 3, c.dy - r * i / 4 + 2), green.withAlpha(160), 9);
    }
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), ring);
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), ring);

    // sweep
    final a = t * 2 * pi;
    final shader = SweepGradient(
      colors: [Colors.transparent, green.withAlpha(110)],
      stops: const [0.8, 1.0],
      transform: GradientRotation(a),
    ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, Paint()..shader = shader);
    canvas.drawLine(c, c + Offset(cos(a), sin(a)) * r, Paint()..color = green..strokeWidth = 1.5);

    // blips
    for (final d in devices) {
      final p = blip(d, c, r, range);
      final outside = (d.distance ?? 0) > range;
      if (d.isSuspect) {
        final pulse = (t * 2) % 1;
        canvas.drawCircle(
          p,
          8 + 10 * pulse,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Color.fromRGBO(255, 50, 50, 1 - pulse),
        );
      }
      canvas.drawCircle(
        p,
        5,
        Paint()
          ..color = d.kind.color
          ..strokeWidth = 2
          ..style = outside ? PaintingStyle.stroke : PaintingStyle.fill,
      );
      if (d.isSuspect || devices.length <= 10) {
        _label(canvas, d.name.isNotEmpty ? d.name : d.kind.label, p + const Offset(8, -6), Colors.white70, 10);
      }
    }
    canvas.drawCircle(c, 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant RadarPainter old) => true;
}
