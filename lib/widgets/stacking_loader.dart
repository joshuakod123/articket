import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// 시안 2d — 티켓 조각이 한 장씩 쌓이는 로딩 애니메이션.
///
/// 서랍을 여는 동안(첫 로드 · 저장소 마이그레이션 · 공유 카드 렌더)
/// 스피너 대신 씁니다. 조각 세 장이 아래에서 차례로 날아와 비뚤게 얹히고,
/// 마지막 장이 앉으면 전체가 옅게 눌렸다가 처음부터 다시 쌓입니다.
///
/// ```dart
/// const Scaffold(
///   backgroundColor: AppColors.bg,
///   body: Center(child: StackingLoader(label: '서랍을 여는 중')),
/// )
/// ```
///
/// 모션 축소 설정(`MediaQuery.disableAnimations`)에서는 쌓임을 멈추고
/// 완성된 뭉치만 보여줍니다.
class StackingLoader extends StatefulWidget {
  const StackingLoader({
    super.key,
    this.size = 132,
    this.label,
    this.period = const Duration(milliseconds: 2200),
  });

  /// 뭉치가 들어갈 정사각 한 변. 조각 폭은 이 값에 비례합니다.
  final double size;

  /// 아래에 붙는 한 줄. 한글이므로 `AppText.ui`로 찍습니다. null이면 없음.
  final String? label;

  final Duration period;

  @override
  State<StackingLoader> createState() => _StackingLoaderState();
}

class _StackingLoaderState extends State<StackingLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final stack = SizedBox(
      width: widget.size,
      height: widget.size,
      child: reduced
          ? const _Pile(progress: 1)
          : AnimatedBuilder(
              animation: _c,
              builder: (_, __) => _Pile(progress: _c.value),
            ),
    );

    if (widget.label == null) return stack;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        stack,
        SizedBox(height: widget.size * 0.16),
        Text(
          widget.label!,
          style: AppText.ui(size: 13, color: AppColors.inkSoft, spacing: 0.4),
        ),
        const SizedBox(height: 6),
        Text(
          'FILING',
          style: AppText.eyebrow(color: AppColors.pulp, size: 9),
        ),
      ],
    );
  }
}

/// 조각 세 장의 배치·회전은 로고 2d와 같은 값입니다(정규화 좌표).
class _Slip {
  const _Slip({
    required this.widthFactor,
    required this.heightFactor,
    required this.left,
    required this.top,
    required this.angle,
    required this.color,
    this.stamp,
  });

  final double widthFactor;
  final double heightFactor;
  final double left;
  final double top;
  final double angle;
  final Color color;

  /// 마지막 장에만 찍히는 활자. ASCII만 (Bodoni).
  final String? stamp;
}

const _slips = <_Slip>[
  _Slip(
    widthFactor: 0.85,
    heightFactor: 0.205,
    left: 0.0,
    top: 0.06,
    angle: -0.105,
    color: AppColors.kraft,
  ),
  _Slip(
    widthFactor: 0.89,
    heightFactor: 0.222,
    left: 0.074,
    top: 0.34,
    angle: 0.035,
    color: AppColors.foil,
  ),
  _Slip(
    widthFactor: 0.925,
    heightFactor: 0.278,
    left: 0.018,
    top: 0.62,
    angle: -0.035,
    color: AppColors.oxblood,
    stamp: 'ADMIT',
  ),
];

class _Pile extends StatelessWidget {
  const _Pile({required this.progress});

  /// 0 → 1 한 바퀴. 0.00~0.78 사이에 세 장이 스태거로 앉고,
  /// 0.86~1.00 에 전체가 살짝 눌렸다가 사라집니다.
  final double progress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, box) {
        final s = box.maxWidth;

        // 마지막에 뭉치 전체가 도장처럼 한 번 눌립니다.
        final settle = Curves.easeOut.transform(
          ((progress - 0.86) / 0.14).clamp(0.0, 1.0),
        );
        final pileScale = 1 - 0.045 * math.sin(settle * math.pi);
        final pileFade = 1 - 0.85 * Curves.easeIn.transform(
          ((progress - 0.94) / 0.06).clamp(0.0, 1.0),
        );

        return Opacity(
          opacity: pileFade,
          child: Transform.scale(
            scale: pileScale,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < _slips.length; i++)
                  _AnimatedSlip(
                    slip: _slips[i],
                    side: s,
                    // 0.00 / 0.22 / 0.44 에서 출발해 0.34초 폭으로 앉습니다.
                    t: Curves.easeOutCubic.transform(
                      ((progress - i * 0.22) / 0.34).clamp(0.0, 1.0),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedSlip extends StatelessWidget {
  const _AnimatedSlip({
    required this.slip,
    required this.side,
    required this.t,
  });

  final _Slip slip;
  final double side;

  /// 0 = 아래에서 대기, 1 = 제자리.
  final double t;

  @override
  Widget build(BuildContext context) {
    final w = side * slip.widthFactor;
    final h = side * slip.heightFactor;

    return Positioned(
      left: side * slip.left,
      top: side * slip.top + (1 - t) * side * 0.42,
      child: Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.rotate(
          // 날아오는 동안엔 더 기울어 있다가 제자리에서 각도를 찾습니다.
          angle: slip.angle * (0.2 + 0.8 * t) + (1 - t) * 0.16,
          child: Container(
            width: w,
            height: h,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: slip.color,
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.16 * t),
                  blurRadius: 8 * t,
                  offset: Offset(0, 3 * t),
                ),
              ],
            ),
            child: slip.stamp == null
                ? null
                : Text(
                    slip.stamp!,
                    style: AppText.wordmark(
                      size: h * 0.5,
                      spacing: h * 0.13,
                      color: AppColors.stock,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
