import 'package:flutter/material.dart';
import '../theme/ticket_design.dart';

/// Original vector poster art. User-selected photos replace it without a network request.
class TicketArtPainter extends CustomPainter {
  const TicketArtPainter(this.design, this.colors);
  final TicketDesign design;
  final List<Color> colors;
  @override
  void paint(Canvas canvas, Size size) {
    final a = colors.isEmpty ? const Color(0xFFB7A3D3) : colors.first;
    final b = colors.length < 2 ? const Color(0xFFEBDD9A) : colors[1];
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / 200, size.height / 240);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 200, 240),
      Paint()..color = const Color(0xFFF4F0E8),
    );
    if (design == TicketDesign.graphic) {
      canvas.drawRect(const Rect.fromLTWH(0, 0, 200, 240), Paint()..color = b);
      canvas.drawPath(
        Path()
          ..moveTo(0, 240)
          ..lineTo(200, 40)
          ..lineTo(200, 240)
          ..close(),
        Paint()..color = const Color(0xFF20221F),
      );
      canvas.drawCircle(const Offset(40, 55), 78, Paint()..color = a);
      canvas.drawPath(
        Path()
          ..moveTo(55, 0)
          ..lineTo(155, 0)
          ..lineTo(0, 170)
          ..lineTo(0, 60)
          ..close(),
        Paint()..color = const Color(0xFFEC654C),
      );
    } else if (design == TicketDesign.scrapbook) {
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(135, 0)
          ..quadraticBezierTo(150, 45, 90, 80)
          ..quadraticBezierTo(15, 70, 0, 140)
          ..close(),
        Paint()..color = a,
      );
      canvas.drawOval(
        const Rect.fromLTWH(20, 205, 170, 22),
        Paint()..color = b.withValues(alpha: .4),
      );
      final vase = Path()
        ..moveTo(58, 107)
        ..lineTo(99, 107)
        ..lineTo(92, 127)
        ..cubicTo(145, 190, 105, 215, 78, 215)
        ..cubicTo(35, 215, 22, 185, 61, 128)
        ..close();
      canvas.drawPath(vase, Paint()..color = const Color(0xFFC87750));
      canvas.drawLine(
        const Offset(79, 110),
        const Offset(120, 30),
        Paint()
          ..color = const Color(0xFF617555)
          ..strokeWidth = 2,
      );
      for (var i = 0; i < 5; i++) {
        canvas.drawOval(
          Rect.fromLTWH(77 + i * 7, 90 - i * 14, 25, 10),
          Paint()..color = const Color(0xFF7E915F),
        );
      }
      canvas.drawPath(
        Path()
          ..moveTo(149, 139)
          ..cubicTo(125, 142, 140, 161, 128, 180)
          ..cubicTo(110, 216, 176, 218, 169, 187)
          ..cubicTo(163, 167, 161, 145, 149, 139)
          ..close(),
        Paint()..color = b,
      );
    } else {
      canvas.drawRect(
        const Rect.fromLTWH(0, 130, 200, 110),
        Paint()..color = b,
      );
      canvas.drawPath(
        Path()
          ..moveTo(20, 240)
          ..lineTo(40, 0)
          ..lineTo(103, 0)
          ..lineTo(160, 240)
          ..close(),
        Paint()..color = a,
      );
      canvas.drawOval(
        const Rect.fromLTWH(85, 30, 145, 170),
        Paint()..color = const Color(0xFFE3B39A),
      );
      canvas.drawRect(
        const Rect.fromLTWH(28, 40, 25, 95),
        Paint()..color = const Color(0xFF3F5D67),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(TicketArtPainter old) =>
      old.design != design || old.colors != colors;
}
