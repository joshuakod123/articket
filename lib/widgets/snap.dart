import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 어떤 축이 눈금에 걸렸는지.
enum SnapAxis { x, y, rotation, scale }

/// 스냅을 적용한 결과.
class SnapOutcome {
  const SnapOutcome({
    required this.dx,
    required this.dy,
    required this.rotation,
    required this.scale,
    required this.engaged,
    required this.justEngaged,
  });

  final double dx;
  final double dy;
  final double rotation;
  final double scale;

  /// 지금 걸려 있는 축들. 가이드선을 그릴 때 씁니다.
  final Set<SnapAxis> engaged;

  /// 이번 프레임에 **새로** 걸린 축이 있는지. 촉감은 여기서만 울립니다.
  final bool justEngaged;

  bool has(SnapAxis a) => engaged.contains(a);
}

/// 스크랩북 편집용 눈금.
///
/// ## 왜 필요한가
///
/// 지금까지 회전과 위치가 완전히 자유각이었습니다. 스티커 두 개를 나란히
/// 놓으려 해도 0.3도씩 어긋나고, 페이지 한가운데에 정확히 앉히려면 손이 떨립니다.
/// 눈금이 없으니 **정돈된 배치가 사실상 불가능**했습니다.
///
/// ## 왜 0도만 눈금이 아닌가
///
/// 이 앱은 손으로 붙인 스크랩북입니다. 모든 게 정확히 0도로 붙으면
/// 인쇄된 카탈로그처럼 보이지 손으로 만든 물건처럼 보이지 않습니다.
/// 그래서 눈금을 **0° · ±5° · ±10° · ±15°** 로 두었습니다. 사용자가
/// "적당히 비뚤게"를 재현 가능하게 고를 수 있습니다.
///
/// 대신 0°의 허용 폭은 일부러 좁혔습니다([_kZeroTolerance]). 스크랩북에서
/// 완전히 수평인 건 오히려 예외적인 선택이라, 지나가다 얻어걸리면 안 됩니다.
///
/// ## 쓰는 법
///
/// 제스처마다 인스턴스를 새로 만들지 말고, 하나를 들고 [begin]으로 초기화합니다.
///
/// ```dart
/// onScaleStart: () => _snap.begin(),
/// onScaleUpdate: (d) {
///   final s = _snap.apply(dx: ..., dy: ..., rotation: ..., scale: ...);
///   if (s.justEngaged) Feel.snap();
///   setState(() { layer.dx = s.dx; ... });
/// },
/// ```
class SnapEngine {
  SnapEngine({this.enabled = true});

  /// 꺼두면 [apply]가 입력을 그대로 돌려줍니다. 정밀 배치를 원하는
  /// 사용자를 위한 탈출구입니다.
  bool enabled;

  final Set<SnapAxis> _engaged = <SnapAxis>{};

  /// 제스처가 시작될 때 부릅니다. 이전 제스처에서 걸려 있던 기억을 지웁니다.
  /// 이걸 빼먹으면 두 번째 제스처에서 촉감이 안 울립니다.
  void begin() => _engaged.clear();

  /// 손을 뗐을 때. [begin]과 같지만 의도가 다르니 이름을 나눠 둡니다.
  void end() => _engaged.clear();

  /// 손으로 잡은 값들을 눈금에 붙입니다.
  ///
  /// - [dx] / [dy] 는 캔버스 대비 0.0~1.0 비율.
  /// - [rotation] 은 라디안.
  /// - [scale] 은 배율.
  /// - [scaleGuides] 에 형제 레이어들의 배율을 넘기면 "옆 것과 같은 크기"에
  ///   걸립니다. 스크랩북에서 스티커 크기를 맞추는 흔한 동작입니다.
  /// - [snapRotation] / [snapScale] 은 손가락이 하나일 때 꺼둡니다.
  ///   한 손가락 드래그 중에는 회전·크기를 건드리지 않으니, 그때까지 눈금을
  ///   물리면 정지해 있는 값이 계속 "새로 걸린" 것으로 잡힙니다.
  SnapOutcome apply({
    required double dx,
    required double dy,
    required double rotation,
    required double scale,
    List<double> xGuides = kGuides,
    List<double> yGuides = kGuides,
    List<double> scaleGuides = const <double>[],
    bool snapRotation = true,
    bool snapScale = true,
  }) {
    if (!enabled) {
      return SnapOutcome(
        dx: dx,
        dy: dy,
        rotation: rotation,
        scale: scale,
        engaged: const <SnapAxis>{},
        justEngaged: false,
      );
    }

    final now = <SnapAxis>{};

    final sx = _nearest(dx, xGuides, _kPositionTolerance);
    if (sx != null) now.add(SnapAxis.x);

    final sy = _nearest(dy, yGuides, _kPositionTolerance);
    if (sy != null) now.add(SnapAxis.y);

    double? sr;
    if (snapRotation) {
      sr = _nearestAngle(rotation);
      if (sr != null) now.add(SnapAxis.rotation);
    }

    double? ss;
    if (snapScale) {
      ss = _nearest(scale, [1.0, ...scaleGuides], _kScaleTolerance);
      if (ss != null) now.add(SnapAxis.scale);
    }

    // 이번에 **새로** 들어온 축이 있는지. 머무는 동안에는 조용합니다.
    final fresh = now.difference(_engaged).isNotEmpty;

    _engaged
      ..clear()
      ..addAll(now);

    return SnapOutcome(
      dx: sx ?? dx,
      dy: sy ?? dy,
      rotation: sr ?? rotation,
      scale: ss ?? scale,
      engaged: now,
      justEngaged: fresh,
    );
  }

  // ── 눈금 ────────────────────────────────────────

  /// 가로/세로 안내선. 가운데와 삼등분.
  static const List<double> kGuides = [0.5, 1 / 3, 2 / 3];

  /// 페이지 여백까지 포함한 안내선. 큰 캔버스(스크랩북 페이지)용.
  static const List<double> kPageGuides = [0.5, 1 / 3, 2 / 3, 0.25, 0.75];

  /// 회전 눈금(도). 0°는 있되 걸리기 어렵게 해둡니다.
  static const List<double> kAngleDegrees = [0, 5, -5, 10, -10, 15, -15];

  static const double _kPositionTolerance = 0.018;
  static const double _kScaleTolerance = 0.045;

  /// 회전 허용 폭(도). 0°만 좁습니다.
  static const double _kAngleTolerance = 1.8;
  static const double _kZeroTolerance = 0.9;

  static double? _nearest(double v, List<double> guides, double tolerance) {
    double? best;
    var bestGap = tolerance;
    for (final g in guides) {
      final gap = (v - g).abs();
      if (gap < bestGap) {
        bestGap = gap;
        best = g;
      }
    }
    return best;
  }

  /// 회전은 한 바퀴 단위로 접어서 비교합니다.
  /// 370도로 돌려도 10도 눈금에 걸려야 하니까요.
  static double? _nearestAngle(double radians) {
    const twoPi = math.pi * 2;
    final turns = (radians / twoPi).roundToDouble();
    final folded = radians - turns * twoPi; // -π ~ π
    final deg = folded * 180 / math.pi;

    double? best;
    var bestGap = double.infinity;

    for (final target in kAngleDegrees) {
      final tolerance = target == 0 ? _kZeroTolerance : _kAngleTolerance;
      final gap = (deg - target).abs();
      if (gap <= tolerance && gap < bestGap) {
        bestGap = gap;
        best = target;
      }
    }

    if (best == null) return null;
    return best * math.pi / 180 + turns * twoPi;
  }
}

/// 눈금에 걸린 축을 얇은 실선으로 비춥니다.
///
/// 촉감만으로는 "무엇에" 걸렸는지 알 수 없습니다. 가운데인지 삼등분인지,
/// 회전이 0도인지 10도인지. 선이 한 줄 뜨면 그 애매함이 사라집니다.
///
/// 선은 **황동색 반투명**입니다. 편집 보조선이 종이보다 튀면 안 되니까요.
class SnapGuides extends StatelessWidget {
  const SnapGuides({super.key, required this.engaged, this.color});

  final Set<SnapAxis> engaged;

  /// 기본값은 앱 팔레트의 `foil`. 테마를 안 물리려고 인자로 받습니다.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (engaged.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: CustomPaint(
        painter: _GuidePainter(
          engaged: engaged,
          color: color ?? const Color(0xFF8C7134),
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _GuidePainter extends CustomPainter {
  _GuidePainter({required this.engaged, required this.color});

  final Set<SnapAxis> engaged;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 0.9;

    // 세로선 — 가로 자리가 걸렸을 때.
    if (engaged.contains(SnapAxis.x)) {
      final x = size.width / 2;
      _dashed(canvas, paint, Offset(x, 0), Offset(x, size.height));
    }

    // 가로선 — 세로 자리가 걸렸을 때.
    if (engaged.contains(SnapAxis.y)) {
      final y = size.height / 2;
      _dashed(canvas, paint, Offset(0, y), Offset(size.width, y));
    }

    // 회전·크기는 선으로 표현할 게 없어서, 모서리에 작은 표식을 찍습니다.
    if (engaged.contains(SnapAxis.rotation) ||
        engaged.contains(SnapAxis.scale)) {
      final dot = Paint()..color = color.withValues(alpha: 0.75);
      canvas.drawCircle(Offset(size.width - 9, 9), 2.4, dot);
    }
  }

  /// 실선보다 점선이 "보조선"으로 읽힙니다.
  void _dashed(Canvas canvas, Paint paint, Offset from, Offset to) {
    const dash = 4.0;
    const gap = 4.0;
    final total = (to - from).distance;
    if (total <= 0) return;
    final step = (to - from) / total;

    var travelled = 0.0;
    while (travelled < total) {
      final end = math.min(travelled + dash, total);
      canvas.drawLine(
        from + step * travelled,
        from + step * end,
        paint,
      );
      travelled = end + gap;
    }
  }

  @override
  bool shouldRepaint(_GuidePainter old) =>
      old.engaged.length != engaged.length ||
          !old.engaged.containsAll(engaged) ||
          old.color != color;
}