import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'paper.dart';

// ─────────────────────────────────────────────────────────────
// 속지의 결
// ─────────────────────────────────────────────────────────────

/// 노트 속지의 아주 옅은 모눈 점.
class DotGridPainter extends CustomPainter {
  DotGridPainter({this.step = 22, this.color = AppColors.pulp});

  final double step;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.55);
    for (double y = step; y < size.height; y += step) {
      for (double x = step; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 0.7, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DotGridPainter old) => false;
}

/// 오래된 종이에 번진 누런 얼룩(foxing).
///
/// 종이가 "새 A4"처럼 보이는 가장 큰 이유는 얼룩이 하나도 없기 때문입니다.
/// 아주 옅은 갈색 원을 몇 개만 흩뿌려도 나이가 확 듭니다.
class FoxingPainter extends CustomPainter {
  FoxingPainter({this.seed = 3, this.strength = 1.0});

  final int seed;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0) return;
    final rng = math.Random(seed);
    final n = (size.width * size.height / 26000).clamp(4, 26).toInt();

    for (var i = 0; i < n; i++) {
      final c = Offset(
        rng.nextDouble() * size.width,
        rng.nextDouble() * size.height,
      );
      final r = 5 + rng.nextDouble() * 26;
      final a = (0.020 + rng.nextDouble() * 0.038) * strength;

      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFF8A6A3A).withValues(alpha: a),
              const Color(0xFF8A6A3A).withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(FoxingPainter old) =>
      old.seed != seed || old.strength != strength;
}

/// 손으로 뜯어낸 종이 가장자리(deckle edge).
///
/// 직선으로 자른 종이는 인쇄물이고, 결을 따라 뜯긴 종이는 물건입니다.
/// 오른쪽 바깥 변만 미세하게 흔들어 뜯긴 결을 냅니다.
class DeckleEdgePainter extends CustomPainter {
  DeckleEdgePainter({this.seed = 5, this.depth = 3.0, this.color = AppColors.bg});

  final int seed;

  /// 뜯긴 폭.
  final double depth;

  /// 종이 바깥(배경) 색. 이 색으로 가장자리를 깎아냅니다.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final path = Path()..moveTo(size.width, 0);

    var y = 0.0;
    while (y < size.height) {
      y += 5 + rng.nextDouble() * 9;
      final x = size.width - rng.nextDouble() * depth;
      path.lineTo(x, math.min(y, size.height));
    }
    path
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, Paint()..color = color);

    // 뜯긴 자리에 생기는 얇은 그늘.
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF6B5A40).withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(DeckleEdgePainter old) => old.seed != seed;
}

/// 페이지가 바깥쪽으로 살짝 들리며 지는 그늘.
class PageCurl extends StatelessWidget {
  const PageCurl({super.key, this.width = 26});

  final double width;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: width,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                const Color(0xFF6B5A40).withValues(alpha: 0.05),
                const Color(0xFF6B5A40).withValues(alpha: 0.13),
              ],
              stops: const [0.0, 0.65, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

/// 제본된 안쪽 여백. 왼쪽에 그늘과 실 박음질이 지나갑니다.
class BindingGutter extends StatelessWidget {
  const BindingGutter({super.key, this.width = 32});

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
                      AppColors.ink.withValues(alpha: 0.16),
                      AppColors.ink.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
            // 제본 구멍과 실.
            Positioned(
              left: width * 0.58,
              top: 16,
              bottom: 16,
              width: 6,
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
    final thread = Paint()
      ..color = AppColors.inkSoft.withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final hole = Paint()..color = AppColors.ink.withValues(alpha: 0.30);
    final rim = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    const dash = 9.0;
    const gap = 8.0;
    final x = size.width / 2;

    for (double y = 0; y < size.height; y += dash + gap) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, math.min(y + dash, size.height)),
        thread,
      );
      // 실이 들어간 구멍.
      canvas.drawCircle(Offset(x, y), 1.5, hole);
      canvas.drawCircle(Offset(x, y), 1.5, rim);
    }
  }

  @override
  bool shouldRepaint(_StitchPainter old) => false;
}

// ─────────────────────────────────────────────────────────────
// 페이지
// ─────────────────────────────────────────────────────────────

/// 스크랩북 한 페이지.
///
/// 종이 한 장에 여섯 겹이 올라갑니다.
/// 바탕 지질 → 빛 방향 → 모눈 점 → 오래된 얼룩 → 제본 그늘 → 바깥 뜯긴 결.
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
    return Stack(
      children: [
        // 1) 지질.
        Positioned.fill(
          child: PaperSurface(
            color: AppColors.stockLight,
            grain: 0.062,
            fiber: 0.75,
            seed: seed,
            child: const SizedBox.expand(),
          ),
        ),

        // 2) 빛. 왼쪽 위에서 들어와 오른쪽 아래로 가라앉습니다.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.30),
                    Colors.transparent,
                    const Color(0xFF6B5A40).withValues(alpha: 0.06),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
        ),

        // 3) 모눈 점 + 4) 얼룩.
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: DotGridPainter(),
                foregroundPainter: FoxingPainter(seed: seed * 7 + 1),
              ),
            ),
          ),
        ),

        // 5) 제본.
        const Positioned(left: 0, top: 0, bottom: 0, child: BindingGutter()),

        // 6) 바깥으로 들린 결 + 뜯긴 가장자리.
        const Positioned(right: 0, top: 0, bottom: 0, child: PageCurl()),
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: DeckleEdgePainter(seed: seed * 3 + 5),
              ),
            ),
          ),
        ),

        // ── 내용 ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(44, 18, 24, 14),
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
              // 머리말 아래 이중 괘선. 위는 진하고 아래는 옅게.
              Container(height: 1, color: AppColors.line),
              const SizedBox(height: 2),
              Container(
                height: 1,
                color: AppColors.line.withValues(alpha: 0.45),
              ),
              const SizedBox(height: 12),
              Expanded(child: child),
              const SizedBox(height: 8),
              Text(
                footer,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style:
                AppText.data(size: 8, spacing: 1.6, color: AppColors.pulp),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 붙이는 것들
// ─────────────────────────────────────────────────────────────

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
                        Colors.white.withValues(alpha: 0.24),
                        Colors.white.withValues(alpha: 0.02),
                        Colors.white.withValues(alpha: 0.17),
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
                // 테이프가 종이에 눌리며 생긴 미세한 주름.
                CustomPaint(painter: _TapeCreasePainter()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TapeCreasePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(size.width.toInt());
    final p = Paint()..strokeWidth = 0.8;
    for (var i = 0; i < 5; i++) {
      final x = rng.nextDouble() * size.width;
      p.color = Colors.white.withValues(alpha: 0.10 + rng.nextDouble() * 0.10);
      canvas.drawLine(Offset(x, 0), Offset(x + 2, size.height), p);
    }
  }

  @override
  bool shouldRepaint(_TapeCreasePainter old) => false;
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

/// 페이지에 테이프로 붙인 조각. 살짝 비뚤게 앉고, 종이에 그늘을 떨굽니다.
class TapedItem extends StatelessWidget {
  const TapedItem({
    super.key,
    required this.child,
    this.angle = 0.02,
    this.tapeColor = const Color(0x998C7134),
  });

  final Widget child;
  final double angle;
  final Color tapeColor;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(boxShadow: paperShadow(depth: 0.45)),
            child: child,
          ),
          // 위·아래 대각으로 붙인 테이프 두 조각.
          Positioned(
            left: -14,
            top: -10,
            child: WashiTape(
              width: 62,
              height: 19,
              color: tapeColor,
              angle: -0.72,
            ),
          ),
          Positioned(
            right: -14,
            bottom: -10,
            child: WashiTape(
              width: 62,
              height: 19,
              color: tapeColor,
              angle: -0.72,
            ),
          ),
        ],
      ),
    );
  }
}

/// 사진을 끼우는 종이 모서리. 앨범에 사진을 고정하던 그 조각입니다.
class PhotoCorner extends StatelessWidget {
  const PhotoCorner({
    super.key,
    this.size = 18,
    this.color = const Color(0x66251E15),
    this.quarterTurns = 0,
  });

  final double size;
  final Color color;
  final int quarterTurns;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RotatedBox(
        quarterTurns: quarterTurns,
        child: CustomPaint(
          size: Size.square(size),
          painter: _CornerPainter(color: color),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  _CornerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(0, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_CornerPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────
// 손으로 그은 것들
// ─────────────────────────────────────────────────────────────

/// 손으로 두 번 그은 밑줄. 획이 어긋나서 자로 댄 티가 안 납니다.
class DoodleUnderline extends StatelessWidget {
  const DoodleUnderline({
    super.key,
    this.width = 90,
    this.color = AppColors.foil,
  });

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size(width, 8),
        painter: _UnderlinePainter(color: color),
      ),
    );
  }
}

class _UnderlinePainter extends CustomPainter {
  _UnderlinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 첫 획 — 굵게.
    p.strokeWidth = 2.4;
    canvas.drawPath(
      Path()
        ..moveTo(1, 4)
        ..quadraticBezierTo(size.width * 0.45, 1.2, size.width - 1, 3.6),
      p,
    );

    // 두 번째 획 — 얇게, 살짝 어긋나게.
    p
      ..strokeWidth = 1.1
      ..color = color.withValues(alpha: 0.45);
    canvas.drawPath(
      Path()
        ..moveTo(4, 6.6)
        ..quadraticBezierTo(size.width * 0.55, 4.6, size.width - 6, 6.2),
      p,
    );
  }

  @override
  bool shouldRepaint(_UnderlinePainter old) => old.color != color;
}

/// 여백에 툭 그린 별 하나.
class DoodleStar extends StatelessWidget {
  const DoodleStar({
    super.key,
    this.size = 16,
    this.color = AppColors.oxblood,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.square(size),
        painter: _StarPainter(color: color),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // 한붓그리기 오각별. 손으로 그은 티가 나게 시작점을 조금 넘겨 닫습니다.
    final path = Path();
    final r = size.width * 0.46;
    final c = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i <= 5; i++) {
      final a = -math.pi / 2 + i * 4 * math.pi / 5;
      final pt = Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.color != color;
}