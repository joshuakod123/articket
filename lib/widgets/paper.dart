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
/// 라이트 배경에서는 세피아 톤을 낮은 알파로 깔아야 종이가 벽에서 떠 보입니다.
List<BoxShadow> paperShadow({double depth = 1}) => [
  BoxShadow(
    color: const Color(0xFF3B2F1E).withValues(alpha: 0.18 * depth),
    blurRadius: 22 * depth,
    offset: Offset(0, 10 * depth),
  ),
  BoxShadow(
    color: const Color(0xFF3B2F1E).withValues(alpha: 0.12),
    blurRadius: 2,
    offset: const Offset(0, 1),
  ),
];