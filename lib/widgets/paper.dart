import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 종이 질감. 반점(speckle) 위에 짧은 섬유(fiber)를 눕혀 크라프트지 결을 냅니다.
///
/// 이미지 에셋 없이 CustomPainter로만 찍습니다. 시드가 같으면 무늬도 같습니다.
class GrainPainter extends CustomPainter {
  GrainPainter({
    this.opacity = 0.05,
    this.seed = 7,
    this.fiber = 0.5,
  });

  final double opacity;
  final int seed;

  /// 섬유 결의 양. 0이면 반점만 찍습니다.
  final double fiber;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final area = size.width * size.height;
    final paint = Paint();

    // 1) 종이 반점.
    final speckles = (area / 90).clamp(60, 2400).toInt();
    for (var i = 0; i < speckles; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final dark = rng.nextBool();
      paint.color = (dark ? Colors.black : Colors.white)
          .withValues(alpha: opacity * rng.nextDouble());
      canvas.drawCircle(Offset(x, y), rng.nextDouble() * 0.9, paint);
    }

    if (fiber <= 0) return;

    // 2) 눌린 섬유. 거의 수평으로 짧게 그어 마닐라지 결을 만듭니다.
    final strands = (area / 900 * fiber).clamp(0, 900).toInt();
    final strand = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < strands; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final len = 3 + rng.nextDouble() * 9;
      final tilt = (rng.nextDouble() - 0.5) * 0.5;
      final dark = rng.nextDouble() < 0.55;

      strand
        ..strokeWidth = 0.5 + rng.nextDouble() * 0.5
        ..color = (dark ? Colors.black : Colors.white)
            .withValues(alpha: opacity * 0.85 * rng.nextDouble());

      canvas.drawLine(
        Offset(x, y),
        Offset(x + math.cos(tilt) * len, y + math.sin(tilt) * len),
        strand,
      );
    }
  }

  @override
  bool shouldRepaint(GrainPainter old) => false;
}

/// 화면 전체에 얹는 속지 질감. 콘텐츠 위에 아주 옅게 깝니다.
class WallGrain extends StatelessWidget {
  const WallGrain({super.key, this.opacity = 0.035, this.seed = 3});

  final double opacity;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: GrainPainter(opacity: opacity, seed: seed, fiber: 0.35),
          ),
        ),
      ),
    );
  }
}

/// 티켓/카드/서류철 표면에 종이 질감을 얹는 래퍼.
class PaperSurface extends StatelessWidget {
  const PaperSurface({
    super.key,
    required this.child,
    this.color = AppColors.stock,
    this.grain = 0.055,
    this.seed = 7,
    this.fiber = 0.5,
  });

  final Widget child;
  final Color color;
  final double grain;
  final int seed;
  final double fiber;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Container(color: color),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter:
              GrainPainter(opacity: grain, seed: seed, fiber: fiber),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// 겹쳐 꽂힌 서류가 아래 장에 떨구는 접촉 그림자.
///
/// 위에서 아래로 짙어지므로, 덮는 서류철의 윗변 **바로 위**에 깝니다.
class LayerShadow extends StatelessWidget {
  const LayerShadow({super.key, this.strength = 1.0});

  final double strength;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF3B2F1E).withValues(alpha: 0.0),
              const Color(0xFF3B2F1E).withValues(alpha: 0.10 * strength),
              const Color(0xFF3B2F1E).withValues(alpha: 0.34 * strength),
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// 자이로 각도에 따라 흐르는 홀로그램 펄.
///
/// [tilt]는 -1.0 ~ 1.0. 센서가 없으면 0으로 두면 정지 상태가 됩니다.
class HoloOverlay extends StatelessWidget {
  const HoloOverlay({super.key, required this.tilt, this.strength = 1.0});

  final double tilt;
  final double strength;

  @override
  Widget build(BuildContext context) {
    final shift = tilt.clamp(-1.0, 1.0);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-1 + shift, -1),
            end: Alignment(1 + shift, 1),
            colors: AppColors.holo
                .map((c) => c.withValues(alpha: c.a * strength))
                .toList(),
            stops: const [0.0, 0.35, 0.65, 1.0],
          ),
          backgroundBlendMode: BlendMode.screen,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// 카드 아래 깔리는 종이 두께 그림자.
///
/// 라이트 배경에서는 세피아 톤을 낮은 알파로 깔아야 종이가 벽에서 떠 보입니다.
///
/// ## 그림자가 두 겹인 이유
///
/// 종이 그림자는 하나가 아닙니다.
///
/// - **접촉 그림자** — 종이가 바닥에 닿는 지점 바로 밑. 좁고 진합니다.
/// - **확산 그림자** — 넓게 퍼지는 부드러운 그늘.
///
/// [lift]로 종이를 들어올릴 때 이 둘이 **반대 방향으로 움직여야** 합니다.
/// 바닥에서 떨어지니 접촉 그림자는 흐려지고 약해지고, 대신 확산 그림자가
/// 넓고 멀어집니다. 둘 다 같이 키우면 "그림자가 커졌다"로만 보이고
/// 들어올린 느낌이 안 납니다. 이게 동적 그림자의 핵심입니다.
///
/// [lift]는 0.0(바닥에 붙음) ~ 1.0(손에 들림).
List<BoxShadow> paperShadow({double depth = 1, double lift = 0}) {
  final l = lift.clamp(0.0, 1.0);

  return [
    // 확산 — 들수록 넓고 멀어지되, 픽셀당 농도는 옅어집니다.
    BoxShadow(
      color: const Color(0xFF3B2F1E)
          .withValues(alpha: (0.18 - 0.05 * l) * depth * (1 + 0.5 * l)),
      blurRadius: (22 + 26 * l) * depth,
      offset: Offset(0, (10 + 14 * l) * depth),
    ),
    // 접촉 — 들수록 흐려지고 사라집니다.
    BoxShadow(
      color: const Color(0xFF3B2F1E).withValues(alpha: 0.12 * (1 - l * 0.85)),
      blurRadius: 2 + 3 * l,
      offset: Offset(0, 1 + l),
    ),
  ];
}

/// 집어 든 종이. 그림자와 크기를 함께 움직입니다.
///
/// 그림자만 키우면 "그림자가 커진 종이"로 보입니다. 실제로 물체가 눈에
/// 가까워지면 **살짝 커 보여야** 합니다. 3%면 충분하고, 그 이상은 확대로 읽힙니다.
///
/// ```dart
/// PaperLift(
///   lifted: isDragging,
///   child: TicketFront(ticket: ticket),
/// )
/// ```
class PaperLift extends StatelessWidget {
  const PaperLift({
    super.key,
    required this.lifted,
    required this.child,
    this.depth = 1.0,
    this.borderRadius,
    this.duration = const Duration(milliseconds: 190),
  });

  final bool lifted;
  final Widget child;

  /// 바닥에 붙어 있을 때의 그림자 세기.
  final double depth;

  /// 자식 모서리가 둥글면 넘겨주세요. 안 넘기면 직사각형 그림자입니다.
  final BorderRadius? borderRadius;

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: lifted ? 1.0 : 0.0),
      duration: duration,
      // 종이는 튀지 않습니다. 감쇠된 곡선으로 멎습니다.
      curve: Curves.easeOutCubic,
      builder: (context, t, inner) {
        return Transform.scale(
          scale: 1 + 0.03 * t,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              boxShadow: paperShadow(depth: depth, lift: t),
            ),
            child: inner,
          ),
        );
      },
      child: child,
    );
  }
}