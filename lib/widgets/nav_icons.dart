import 'package:flutter/material.dart';

/// 하단 탭바 심볼.
///
/// 예전 심볼(우표·압정)은 획이 너무 잘고 `Path.combine`으로 구멍을 뚫어서,
/// 20pt로 줄이면 뭉개지거나 아예 안 보였습니다. 여기서는
/// **선 몇 개로만 이루어진 큰 실루엣**으로 다시 그립니다.
/// 전부 정규화 좌표라 어떤 크기에서도 같은 비율로 나옵니다.
enum NavSymbol {
  /// 인덱스 탭이 달린 서류철. 홈(서랍).
  drawer,

  /// 스프링 제본 탁상 달력.
  calendar,

  /// 관람 회원증. 내 기록.
  member,
}

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

  /// 고른 탭만 속을 옅게 채워 도장처럼 눌린 느낌을 냅니다.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
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

  Paint _stroke(double w) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  Paint get _wash => Paint()
    ..color = color.withValues(alpha: 0.18)
    ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    // 획 두께는 아이콘 크기에 비례시킵니다. 22pt 기준 1.5.
    final w = size.width / 22 * 1.5;

    switch (symbol) {
      case NavSymbol.drawer:
        _drawer(canvas, size, w);
      case NavSymbol.calendar:
        _calendar(canvas, size, w);
      case NavSymbol.member:
        _member(canvas, size, w);
    }
  }

  /// 인덱스 탭이 솟은 서류철. 앱 메인 메타포와 같은 모양입니다.
  void _drawer(Canvas canvas, Size size, double w) {
    final sw = size.width;
    final sh = size.height;

    final body = Path()
      ..moveTo(sw * 0.09, sh * 0.82)
      ..lineTo(sw * 0.09, sh * 0.26)
      ..lineTo(sw * 0.42, sh * 0.26)
      ..lineTo(sw * 0.50, sh * 0.38)
      ..lineTo(sw * 0.91, sh * 0.38)
      ..lineTo(sw * 0.91, sh * 0.82)
      ..close();

    if (filled) canvas.drawPath(body, _wash);
    canvas.drawPath(body, _stroke(w));

    // 앞장이 덮인 자리. 서류철이 두 겹이라는 표시.
    canvas.drawLine(
      Offset(sw * 0.09, sh * 0.52),
      Offset(sw * 0.91, sh * 0.52),
      _stroke(w * 0.75),
    );
  }

  /// 스프링 제본 탁상 달력.
  void _calendar(Canvas canvas, Size size, double w) {
    final sw = size.width;
    final sh = size.height;

    final body = RRect.fromRectAndRadius(
      Rect.fromLTRB(sw * 0.09, sh * 0.26, sw * 0.91, sh * 0.86),
      Radius.circular(sw * 0.06),
    );

    if (filled) canvas.drawRRect(body, _wash);
    canvas.drawRRect(body, _stroke(w));

    // 제본 고리 둘.
    for (final x in [sw * 0.33, sw * 0.67]) {
      canvas.drawLine(
        Offset(x, sh * 0.12),
        Offset(x, sh * 0.34),
        _stroke(w),
      );
    }

    // 머리글 칸.
    canvas.drawLine(
      Offset(sw * 0.09, sh * 0.45),
      Offset(sw * 0.91, sh * 0.45),
      _stroke(w * 0.75),
    );

    // 날짜 셋. 이 점들이 "기록이 찍힌 날"입니다.
    final dot = Paint()..color = color;
    for (final x in [sw * 0.30, sw * 0.50, sw * 0.70]) {
      canvas.drawCircle(Offset(x, sh * 0.655), w * 0.62, dot);
    }
  }

  /// 관람 회원증. 왼쪽에 얼굴, 오른쪽에 기재란 두 줄.
  void _member(Canvas canvas, Size size, double w) {
    final sw = size.width;
    final sh = size.height;

    final body = RRect.fromRectAndRadius(
      Rect.fromLTRB(sw * 0.07, sh * 0.24, sw * 0.93, sh * 0.80),
      Radius.circular(sw * 0.05),
    );

    if (filled) canvas.drawRRect(body, _wash);
    canvas.drawRRect(body, _stroke(w));

    // 증명사진: 머리 + 어깨.
    canvas.drawCircle(Offset(sw * 0.31, sh * 0.43), sw * 0.075, _stroke(w * 0.8));
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(sw * 0.31, sh * 0.685),
        width: sw * 0.28,
        height: sh * 0.26,
      ),
      3.14159,
      3.14159,
      false,
      _stroke(w * 0.8),
    );

    // 기재란.
    canvas.drawLine(
      Offset(sw * 0.52, sh * 0.44),
      Offset(sw * 0.84, sh * 0.44),
      _stroke(w * 0.75),
    );
    canvas.drawLine(
      Offset(sw * 0.52, sh * 0.58),
      Offset(sw * 0.76, sh * 0.58),
      _stroke(w * 0.75),
    );
  }

  @override
  bool shouldRepaint(_NavPainter old) =>
      old.color != color || old.filled != filled || old.symbol != symbol;
}