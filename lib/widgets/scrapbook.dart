import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'paper.dart';

/// 노트 속지의 아주 옅은 모눈 점.
class DotGridPainter extends CustomPainter {
  DotGridPainter({this.step = 22, this.color = AppColors.pulp});

  final double step;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.6);
    for (double y = step; y < size.height; y += step) {
      for (double x = step; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 0.7, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DotGridPainter old) => false;
}

/// 제본된 안쪽 여백. 왼쪽에 그늘과 실 박음질이 지나갑니다.
class BindingGutter extends StatelessWidget {
  const BindingGutter({super.key, this.width = 30});

  final double width;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: width,
        child: Stack(
          children: [
            // 페이지가 안쪽으로 말려 들어가며 지는 그늘.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppColors.ink.withValues(alpha: 0.13),
                      AppColors.ink.withValues(alpha: 0.03),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
            // 실 박음질.
            Positioned(
              left: width * 0.62,
              top: 18,
              bottom: 18,
              width: 2,
              child: CustomPaint(painter: _StitchPainter()),
            ),
          ],
        ),
      ),
    );
  }
}

class _StitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.inkSoft.withValues(alpha: 0.45)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    const dash = 7.0;
    const gap = 6.0;
    for (double y = 0; y < size.height; y += dash + gap) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, math.min(y + dash, size.height)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StitchPainter old) => false;
}

/// 스크랩북 한 페이지. 종이 + 모눈 + 제본 + 머리말/꼬리말.
class NotebookPage extends StatelessWidget {
  const NotebookPage({
    super.key,
    required this.child,
    required this.eyebrow,
    required this.title,
    required this.footer,
    this.seed = 11,
  });

  final Widget child;

  /// 왼쪽 위 작은 대문자 라벨.
  final String eyebrow;

  /// 오른쪽 위 라벨.
  final String title;

  /// 페이지 아래 꼬리말.
  final String footer;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(3)),
      child: Stack(
        children: [
          Positioned.fill(
            child: PaperSurface(
              color: AppColors.stockLight,
              grain: 0.05,
              seed: seed,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(painter: DotGridPainter()),
              ),
            ),
          ),
          Positioned(left: 0, top: 0, bottom: 0, child: const BindingGutter()),

          Padding(
            padding: const EdgeInsets.fromLTRB(40, 16, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        eyebrow,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.data(
                            size: 8, spacing: 1.8, color: AppColors.inkSoft),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: AppText.data(
                            size: 8, spacing: 1.8, color: AppColors.inkSoft),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(height: 1, color: AppColors.line),
                const SizedBox(height: 10),
                Expanded(child: child),
                const SizedBox(height: 8),
                Text(
                  footer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: AppText.data(
                      size: 8, spacing: 1.6, color: AppColors.pulp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 마스킹 테이프 한 조각. 짧은 변이 톱니로 뜯겨 있습니다.
class WashiTape extends StatelessWidget {
  const WashiTape({
    super.key,
    this.width = 66,
    this.height = 20,
    this.color = const Color(0x998C7134),
    this.angle = -0.34,
  });

  final double width;
  final double height;
  final Color color;

  /// 라디안.
  final double angle;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.rotate(
        angle: angle,
        child: ClipPath(
          clipper: _TapeClipper(),
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: color),
                // 테이프 표면의 광택 결.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.22),
                        Colors.white.withValues(alpha: 0.02),
                        Colors.white.withValues(alpha: 0.16),
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TapeClipper extends CustomClipper<Path> {
  static const _teeth = 5;
  static const _bite = 3.0;

  @override
  Path getClip(Size size) {
    final step = size.height / _teeth;
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0);

    for (var i = 1; i <= _teeth; i++) {
      p.lineTo(size.width - (i.isOdd ? _bite : 0.0), step * i);
    }
    p.lineTo(0, size.height);
    for (var i = _teeth - 1; i >= 0; i--) {
      p.lineTo(i.isOdd ? _bite : 0.0, step * i);
    }
    return p..close();
  }

  @override
  bool shouldReclip(_TapeClipper old) => false;
}

/// 페이지에 테이프로 붙인 조각. 살짝 비뚤게 앉습니다.
class TapedItem extends StatelessWidget {
  const TapedItem({
    super.key,
    required this.child,
    this.angle = 0.02,
    this.tapeColor = const Color(0x998C7134),
    this.secondTape = true,
  });

  final Widget child;
  final double angle;
  final Color tapeColor;
  final bool secondTape;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(boxShadow: paperShadow(depth: 0.4)),
            child: child,
          ),
          Positioned(
            top: -10,
            left: -16,
            child: WashiTape(color: tapeColor, angle: -0.52),
          ),
          if (secondTape)
            Positioned(
              bottom: -9,
              right: -14,
              child: WashiTape(
                color: tapeColor,
                angle: -0.48,
                width: 58,
                height: 18,
              ),
            ),
        ],
      ),
    );
  }
}

/// 손으로 그린 별. 획이 살짝 어긋나게 그립니다.
class DoodleStar extends StatelessWidget {
  const DoodleStar({super.key, this.size = 34, this.color = AppColors.oxblood});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _StarPainter(color)),
    ),
  );
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(4);
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final path = Path();

    for (var i = 0; i <= 5; i++) {
      // 별을 한 획으로 그리기 위해 두 칸씩 건너뜁니다.
      final a = -math.pi / 2 + (i * 2) * (2 * math.pi / 5);
      final jitter = (rng.nextDouble() - 0.5) * 2.2;
      final p = Offset(
        c.dx + math.cos(a) * (r + jitter),
        c.dy + math.sin(a) * (r + jitter),
      );
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.color != color;
}

/// 손으로 그은 밑줄. 두 번 그은 것처럼 겹칩니다.
class DoodleUnderline extends StatelessWidget {
  const DoodleUnderline({
    super.key,
    this.width = 90,
    this.color = AppColors.foil,
  });

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: SizedBox(
      width: width,
      height: 8,
      child: CustomPaint(painter: _UnderlinePainter(color)),
    ),
  );
}

class _UnderlinePainter extends CustomPainter {
  _UnderlinePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (var pass = 0; pass < 2; pass++) {
      final y = 3.0 + pass * 2.2;
      final path = Path()..moveTo(2, y);
      path.quadraticBezierTo(
        size.width / 2,
        y + (pass.isEven ? -2.4 : 2.0),
        size.width - 2,
        y + (pass.isEven ? 0.6 : -0.8),
      );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_UnderlinePainter old) => old.color != color;
}

/// 종이 모서리를 접어 끼운 사진 코너.
class PhotoCorner extends StatelessWidget {
  const PhotoCorner({super.key, this.size = 16, this.flip = false});

  final double size;
  final bool flip;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Transform.scale(
      scaleX: flip ? -1 : 1,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _CornerPainter()),
      ),
    ),
  );
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.ink.withValues(alpha: 0.72));
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}