import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 티켓 좌우에 반원 타공을 뚫는 클리퍼.
///
/// [stubFraction] 위치에 절취선이 생깁니다. 세로형은 위에서부터,
/// 가로형은 왼쪽에서부터의 비율입니다.
class TicketClipper extends CustomClipper<Path> {
  TicketClipper({
    this.radius = 9,
    this.stubFraction = 0.72,
    this.corner = 4,
    this.vertical = true,
  });

  final double radius;
  final double stubFraction;
  final double corner;
  final bool vertical;

  @override
  Path getClip(Size size) {
    final body = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(corner),
      ));

    final notch = Path();
    if (vertical) {
      final y = size.height * stubFraction;
      notch
        ..addOval(Rect.fromCircle(center: Offset(0, y), radius: radius))
        ..addOval(Rect.fromCircle(center: Offset(size.width, y), radius: radius));
    } else {
      final x = size.width * stubFraction;
      notch
        ..addOval(Rect.fromCircle(center: Offset(x, 0), radius: radius))
        ..addOval(
            Rect.fromCircle(center: Offset(x, size.height), radius: radius));
    }

    return Path.combine(PathOperation.difference, body, notch);
  }

  @override
  bool shouldReclip(TicketClipper old) =>
      old.radius != radius ||
          old.stubFraction != stubFraction ||
          old.vertical != vertical;
}

/// 타공 사이를 잇는 점선. 클리퍼 위에 겹쳐 그립니다.
class PerforationPainter extends CustomPainter {
  PerforationPainter({
    this.stubFraction = 0.72,
    this.vertical = true,
    this.color = AppColors.ink,
    this.inset = 14,
  });

  final double stubFraction;
  final bool vertical;
  final Color color;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;

    const dot = 1.6;
    const gap = 6.0;

    if (vertical) {
      final y = size.height * stubFraction;
      for (double x = inset; x < size.width - inset; x += gap) {
        canvas.drawCircle(Offset(x, y), dot, paint);
      }
    } else {
      final x = size.width * stubFraction;
      for (double y = inset; y < size.height - inset; y += gap) {
        canvas.drawCircle(Offset(x, y), dot, paint);
      }
    }
  }

  @override
  bool shouldRepaint(PerforationPainter old) =>
      old.stubFraction != stubFraction || old.color != color;
}

/// 문자열 해시로 안정적인 바코드를 그립니다.
/// 같은 티켓은 항상 같은 무늬가 나옵니다.
class BarcodePainter extends CustomPainter {
  BarcodePainter({required this.seed, this.color = AppColors.ink});

  final String seed;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed.hashCode);
    final paint = Paint()..color = color;

    double x = 0;
    while (x < size.width) {
      final w = 1.0 + rng.nextInt(3);
      if (rng.nextBool()) {
        canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
      }
      x += w + 1;
    }
  }

  @override
  bool shouldRepaint(BarcodePainter old) => old.seed != seed;
}

/// 바코드 줄무늬.
///
/// 씨앗으로는 **[Ticket.id]** 를 넘기세요. 발권 번호를 넘기면 티켓을 하나
/// 지웠을 때 뒤 티켓들의 번호가 당겨지면서 바코드 무늬까지 통째로 바뀝니다.
class Barcode extends StatelessWidget {
  const Barcode({
    super.key,
    required this.seed,
    this.height = 26,
    this.color = AppColors.ink,
  });

  /// 무늬를 정하는 고정 씨앗.
  final String seed;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: BarcodePainter(seed: seed, color: color)),
    );
  }
}