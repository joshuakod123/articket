import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

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

  /// 밝기 · 크기를 몇 단계로 뭉칠지. 단계를 늘릴수록 원본에 가깝지만
  /// 그만큼 draw 호출이 늘어납니다. 4 × 3 이면 눈으로는 구분이 안 됩니다.
  static const _alphaSteps = 4;
  static const _sizeSteps = 3;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rng = math.Random(seed);
    final area = size.width * size.height;

    // 1) 종이 반점.
    //
    // 예전에는 점 하나마다 `drawCircle`을 불렀습니다. 전체 화면이면
    // **한 번 그릴 때 2400번**입니다. 화면이 갈아 끼워지는 순간에는 나가는
    // 화면과 들어오는 화면의 결이 같은 프레임에서 처음 그려지므로 그 값이
    // 두 배가 되고, 그 프레임이 눈에 띄게 밀립니다.
    //
    // 난수 소비 순서는 그대로 두고(= 무늬가 바뀌지 않습니다) 밝기·크기가
    // 비슷한 점끼리 묶어 `drawRawPoints`로 한 번에 찍습니다.
    // 2400회 → 최대 24회.
    final speckles = (area / 90).clamp(60, 2400).toInt();
    final buckets = List.generate(
      2 * _alphaSteps * _sizeSteps,
          (_) => <double>[],
      growable: false,
    );

    for (var i = 0; i < speckles; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final dark = rng.nextBool();
      final alpha = rng.nextDouble();
      final radius = rng.nextDouble() * 0.9;

      final ai = (alpha * _alphaSteps).floor().clamp(0, _alphaSteps - 1);
      final si = (radius / 0.9 * _sizeSteps).floor().clamp(0, _sizeSteps - 1);
      final b = ((dark ? 1 : 0) * _alphaSteps + ai) * _sizeSteps + si;

      buckets[b]
        ..add(x)
        ..add(y);
    }

    // `StrokeCap.round` + `PointMode.points` = 지름이 strokeWidth 인 동그란 점.
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var b = 0; b < buckets.length; b++) {
      final pts = buckets[b];
      if (pts.isEmpty) continue;

      final si = b % _sizeSteps;
      final ai = (b ~/ _sizeSteps) % _alphaSteps;
      final dark = b ~/ (_sizeSteps * _alphaSteps) == 1;

      paint
        ..color = (dark ? Colors.black : Colors.white)
            .withValues(alpha: opacity * (ai + 0.5) / _alphaSteps)
        ..strokeWidth = 2 * 0.9 * (si + 0.5) / _sizeSteps;

      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.fromList(pts),
        paint,
      );
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
///
/// ⚠️ 이 위젯은 **자기 자신이 이미 `Positioned.fill`** 입니다.
/// `Stack`의 자식으로 그냥 넣으세요.
///
/// ```dart
/// Stack(children: [ ..., const WallGrain(opacity: .05, seed: 11) ])
/// ```
///
/// `Positioned.fill(child: WallGrain(...))`처럼 한 번 더 감싸면 같은
/// RenderObject에 `StackParentData`를 쓰는 ParentDataWidget이 둘이 되어
/// "Competing ParentDataWidgets are providing parent data to the same
/// RenderObject" 어서션이 납니다. (실제로 `auth_screen.dart`가 그랬고,
/// 로그아웃해서 로그인 화면이 지어질 때마다 이 예외가 떴습니다.)
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
    // ⚠️ 바탕색과 결은 **크기를 만들지 않습니다.**
    //
    // 예전에는 바탕이 `Container(color: color)` 한 장으로 Stack의 첫 자식,
    // 그것도 non-positioned 자식이었습니다. 그래서 Stack의 크기를 [child]가
    // 아니라 **바탕이** 정했고, 들어오는 제약에 따라 두 가지로 어긋났습니다.
    //
    // | 들어오는 높이 제약 | 그때 Container | 결과 |
    // |---|---|---|
    // | 유계 (예: 모달 시트) | 최대치까지 늘어남 | 내용이 짧아도 **화면을 꽉 채움** |
    // | 무계 (예: `Positioned(bottom:)`) | 0으로 접힘 | **바탕색이 아예 안 칠해짐** |
    //
    // 앞의 것이 "티켓 만드는 법" 시트가 상태 바까지 올라간 이유고,
    // 뒤의 것이 종이 쪽지 알림이 반투명해 보인 이유입니다. 둘 다 같은 줄에서
    // 났습니다. 이제 바탕도 결도 `Positioned.fill` 이라 Stack의 크기는
    // 오직 [child] 가 정하고, 바탕은 그 크기에 정확히 맞춰 칠해집니다.
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(child: ColoredBox(color: color)),
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