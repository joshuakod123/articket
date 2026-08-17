import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 하단 탭바 심볼.
///
/// 머티리얼 기본 아이콘 대신 우표·가격표·날짜 스탬프·압정을 직접 그립니다.
/// 전부 획(stroke) 기반이고, 선택된 탭만 속을 옅게 채워 도장처럼 눌린 느낌을 냅니다.
enum NavSymbol { stamp, tag, dateStamp, pin }

class NavIcon extends StatelessWidget {
  const NavIcon({
    super.key,
    required this.symbol,
    required this.color,
    this.size = 22,
    this.filled = false,
  });

  final NavSymbol symbol;
  final Color color;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _NavPainter(symbol: symbol, color: color, filled: filled),
      ),
    );
  }
}

class _NavPainter extends CustomPainter {
  _NavPainter({
    required this.symbol,
    required this.color,
    required this.filled,
  });

  final NavSymbol symbol;
  final Color color;
  final bool filled;

  Paint get _stroke => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  Paint get _wash => Paint()..color = color.withValues(alpha: 0.22);

  @override
  void paint(Canvas canvas, Size size) {
    switch (symbol) {
      case NavSymbol.stamp:
        _stamp(canvas, size);
      case NavSymbol.tag:
        _tag(canvas, size);
      case NavSymbol.dateStamp:
        _dateStamp(canvas, size);
      case NavSymbol.pin:
        _pin(canvas, size);
    }
  }

  /// 우표. 사방이 스캘럽으로 뜯긴 사각형.
  void _stamp(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(2.5, 2.0, size.width - 5, size.height - 5);
    const step = 3.4;
    const bite = 1.5;

    var body = Path()..addRect(r);
    final holes = Path();
    for (double x = r.left + step / 2; x < r.right; x += step) {
      holes
        ..addOval(Rect.fromCircle(center: Offset(x, r.top), radius: bite))
        ..addOval(Rect.fromCircle(center: Offset(x, r.bottom), radius: bite));
    }
    for (double y = r.top + step / 2; y < r.bottom; y += step) {
      holes
        ..addOval(Rect.fromCircle(center: Offset(r.left, y), radius: bite))
        ..addOval(Rect.fromCircle(center: Offset(r.right, y), radius: bite));
    }
    body = Path.combine(PathOperation.difference, body, holes);

    if (filled) canvas.drawPath(body, _wash);
    canvas.drawPath(body, _stroke..strokeWidth = 1.2);
    canvas.drawRect(r.deflate(3.6), _stroke..strokeWidth = 0.9);
  }

  /// 가격표. 실을 꿴 구멍이 뚫린 태그.
  void _tag(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.20, h * 0.17)
      ..lineTo(w * 0.60, h * 0.17)
      ..lineTo(w * 0.87, h * 0.50)
      ..lineTo(w * 0.60, h * 0.83)
      ..lineTo(w * 0.20, h * 0.83)
      ..close();

    if (filled) canvas.drawPath(path, _wash);
    canvas.drawPath(path, _stroke);
    canvas.drawCircle(Offset(w * 0.34, h * 0.50), 2.0, _stroke..strokeWidth = 1.2);
  }

  /// 날짜 스탬프. 고리 두 개가 달린 달력 한 장.
  void _dateStamp(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(2.5, h * 0.26, w - 5, h * 0.60),
      const Radius.circular(2),
    );

    if (filled) canvas.drawRRect(body, _wash);
    canvas.drawRRect(body, _stroke);

    for (final x in [w * 0.34, w * 0.66]) {
      canvas.drawLine(Offset(x, h * 0.11), Offset(x, h * 0.32), _stroke);
    }
    canvas.drawLine(
      Offset(w * 0.16, h * 0.46),
      Offset(w * 0.84, h * 0.46),
      _stroke..strokeWidth = 1.0,
    );
  }

  /// 압정. 머리와 침.
  void _pin(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final head = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w / 2, h * 0.36),
        width: w * 0.54,
        height: h * 0.30,
      ),
      const Radius.circular(5),
    );

    if (filled) canvas.drawRRect(head, _wash);
    canvas.drawRRect(head, _stroke);

    canvas.drawLine(Offset(w / 2, h * 0.52), Offset(w / 2, h * 0.87), _stroke);

    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w / 2, h * 0.22),
        width: w * 0.34,
        height: h * 0.22,
      ),
      math.pi,
      math.pi,
      false,
      _stroke..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_NavPainter old) =>
      old.color != color || old.filled != filled || old.symbol != symbol;
}