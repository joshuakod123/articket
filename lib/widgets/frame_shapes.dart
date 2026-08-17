import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/ticket.dart';

/// 프레임별 실루엣을 실제 Path로 깎습니다.
/// 이미지 에셋 없이 절취선·퍼포레이션·톱니를 전부 그립니다.
CustomClipper<Path> clipperFor(TicketFrame frame) {
  switch (frame) {
    case TicketFrame.classic:
      return _NotchClipper(vertical: true, at: 0.70);
    case TicketFrame.stub:
      return _NotchClipper(vertical: false, at: 0.68);
    case TicketFrame.receipt:
      return _ReceiptClipper();
    case TicketFrame.filmStrip:
      return _FilmClipper();
    case TicketFrame.stamp:
      return _StampClipper();
    case TicketFrame.minimal:
      return _RoundClipper(radius: 16);
  }
}

/// 좌우(또는 상하)에 반원 타공을 뚫는 표준 티켓.
class _NotchClipper extends CustomClipper<Path> {
  _NotchClipper({required this.vertical, required this.at, this.radius = 9});

  final bool vertical;
  final double at;
  final double radius;

  @override
  Path getClip(Size size) {
    final body = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(4)));

    final holes = Path();
    if (vertical) {
      final y = size.height * at;
      holes
        ..addOval(Rect.fromCircle(center: Offset(0, y), radius: radius))
        ..addOval(Rect.fromCircle(center: Offset(size.width, y), radius: radius));
    } else {
      final x = size.width * at;
      holes
        ..addOval(Rect.fromCircle(center: Offset(x, 0), radius: radius))
        ..addOval(
            Rect.fromCircle(center: Offset(x, size.height), radius: radius));
    }
    return Path.combine(PathOperation.difference, body, holes);
  }

  @override
  bool shouldReclip(_NotchClipper old) =>
      old.vertical != vertical || old.at != at;
}

/// 아래쪽이 찢겨나간 영수증.
class _ReceiptClipper extends CustomClipper<Path> {
  static const _tooth = 9.0;

  @override
  Path getClip(Size size) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - _tooth);

    // 톱니를 오른쪽에서 왼쪽으로 그려 내려옵니다.
    var x = size.width;
    var up = false;
    while (x > 0) {
      x -= _tooth;
      p.lineTo(math.max(x, 0), up ? size.height - _tooth : size.height);
      up = !up;
    }
    return p
      ..lineTo(0, size.height - _tooth)
      ..close();
  }

  @override
  bool shouldReclip(_ReceiptClipper old) => false;
}

/// 양옆에 필름 퍼포레이션이 뚫린 프레임.
class _FilmClipper extends CustomClipper<Path> {
  static const _hole = Size(7, 10);
  static const _gap = 18.0;
  static const _inset = 6.0;

  @override
  Path getClip(Size size) {
    final body = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(3)));

    final holes = Path();
    for (double y = _gap; y < size.height - _gap; y += _gap) {
      holes
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(_inset, y, _hole.width, _hole.height),
          const Radius.circular(1.5),
        ))
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width - _inset - _hole.width, y, _hole.width,
              _hole.height),
          const Radius.circular(1.5),
        ));
    }
    return Path.combine(PathOperation.difference, body, holes);
  }

  @override
  bool shouldReclip(_FilmClipper old) => false;
}

/// 우표처럼 사방이 스캘럽으로 뜯긴 프레임.
class _StampClipper extends CustomClipper<Path> {
  static const _r = 4.5;
  static const _step = 13.0;

  @override
  Path getClip(Size size) {
    final body = Path()..addRect(Offset.zero & size);
    final holes = Path();

    for (double x = _step / 2; x < size.width; x += _step) {
      holes
        ..addOval(Rect.fromCircle(center: Offset(x, 0), radius: _r))
        ..addOval(Rect.fromCircle(center: Offset(x, size.height), radius: _r));
    }
    for (double y = _step / 2; y < size.height; y += _step) {
      holes
        ..addOval(Rect.fromCircle(center: Offset(0, y), radius: _r))
        ..addOval(Rect.fromCircle(center: Offset(size.width, y), radius: _r));
    }
    return Path.combine(PathOperation.difference, body, holes);
  }

  @override
  bool shouldReclip(_StampClipper old) => false;
}

/// 절취선 없는 매끈한 카드.
class _RoundClipper extends CustomClipper<Path> {
  _RoundClipper({this.radius = 16});
  final double radius;

  @override
  Path getClip(Size size) => Path()
    ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size, Radius.circular(radius)));

  @override
  bool shouldReclip(_RoundClipper old) => old.radius != radius;
}

/// 절취선 점선. 프레임이 스텁을 가질 때만 그립니다.
class PerforationLine extends StatelessWidget {
  const PerforationLine({
    super.key,
    required this.color,
    this.vertical = false,
    this.inset = 14,
  });

  /// true면 세로 점선(가로형 티켓의 절취선).
  final bool vertical;
  final Color color;
  final double inset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: vertical ? 1 : double.infinity,
      height: vertical ? double.infinity : 1,
      child: CustomPaint(
        painter: _DotPainter(color: color, vertical: vertical, inset: inset),
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  _DotPainter({required this.color, required this.vertical, required this.inset});

  final Color color;
  final bool vertical;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.5);
    const dot = 1.5;
    const gap = 6.0;

    if (vertical) {
      for (double y = inset; y < size.height - inset; y += gap) {
        canvas.drawCircle(Offset(size.width / 2, y), dot, paint);
      }
    } else {
      for (double x = inset; x < size.width - inset; x += gap) {
        canvas.drawCircle(Offset(x, size.height / 2), dot, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPainter old) => old.color != color;
}