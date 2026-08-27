/// 화면 위의 **실제 버튼을 도려내어** 가리키는 안내 막.
///
/// ## 왜 스크린샷이 아니라 도려내기인가
///
/// 흔한 방법은 안내용 이미지를 따로 그려 붙이는 것입니다. 그러면 버튼이
/// 조금만 움직여도 안내가 거짓말을 하기 시작합니다. 여기서는 [GlobalKey]로
/// **지금 화면에 있는 그 위젯의 좌표**를 읽어 그 자리만 비웁니다.
/// 레이아웃이 바뀌면 구멍도 같이 바뀝니다.
///
/// 구멍 테두리에는 인쇄물의 **크롭 마크(재단 표시)** 를 찍습니다. 동그란
/// 스포트라이트를 쓰면 이 앱에서 그것만 다른 재질이 됩니다.
///
/// ## 대상이 없을 수도 있습니다
///
/// 빈 서랍에는 서류철 카드가 한 장도 없습니다. [CoachStep.target]이
/// `null`이거나 아직 레이아웃되지 않았으면 **구멍 없이 가운데 카드만**
/// 띄웁니다. 안내가 통째로 깨지는 것보다 낫습니다.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/feel.dart';

/// 설명 카드를 구멍의 위/아래 어디에 둘지.
enum CoachSide { auto, above, below }

/// 코치 마크 한 단계.
@immutable
class CoachStep {
  const CoachStep({
    required this.eyebrow,
    required this.title,
    required this.body,
    this.target,
    this.pad = const EdgeInsets.all(10),
    this.radius = 6,
    this.side = CoachSide.auto,
  });

  /// 도려낼 위젯. null 이면 구멍 없이 카드만 띄웁니다.
  final GlobalKey? target;

  /// 'STEP 01' 같은 타자기체 라벨.
  final String eyebrow;

  final String title;
  final String body;

  /// 구멍을 대상보다 이만큼 넓게 뚫습니다.
  final EdgeInsets pad;

  final double radius;

  /// 설명 카드를 구멍 위/아래 어디에 둘지. 기본은 자리를 보고 정합니다.
  final CoachSide side;
}

/// 코치 마크를 띄우고, 사용자가 끝까지 보거나 건너뛸 때까지 기다립니다.
Future<void> showCoachMarks(
    BuildContext context, {
      required List<CoachStep> steps,
    }) {
  if (steps.isEmpty) return Future<void>.value();

  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      // 아래 화면이 그대로 보여야 합니다. 그게 이 안내의 전부입니다.
      opaque: false,
      barrierDismissible: false,
      barrierColor: const Color(0x00000000),
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => _CoachLayer(steps: steps),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: anim.drive(CurveTween(curve: Curves.easeOut)),
        child: child,
      ),
    ),
  );
}

class _CoachLayer extends StatefulWidget {
  const _CoachLayer({required this.steps});

  final List<CoachStep> steps;

  @override
  State<_CoachLayer> createState() => _CoachLayerState();
}

class _CoachLayerState extends State<_CoachLayer> {
  int _i = 0;

  CoachStep get _step => widget.steps[_i];

  /// 대상 위젯의 화면 좌표. 못 찾으면 null.
  ///
  /// 이 막은 화면 전체를 덮는 라우트라 좌표계가 화면과 같습니다.
  /// 따로 변환할 것이 없습니다.
  Rect? _holeOf(CoachStep s) {
    final ctx = s.target?.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    if (box.size.isEmpty) return null;
    return s.pad.inflateRect(box.localToGlobal(Offset.zero) & box.size);
  }

  void _next() {
    if (_i >= widget.steps.length - 1) {
      _close();
      return;
    }
    Feel.pick();
    setState(() => _i++);
  }

  void _close() {
    Feel.snap();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final hole = _holeOf(_step);

    // 구멍이 없는 단계는 화면 한가운데의 **크기 0짜리 사각형**으로 둡니다.
    // 이렇게 두면 다음 단계로 넘어갈 때 구멍이 그 자리에서 자라납니다.
    final target = hole ??
        Rect.fromCenter(center: size.center(Offset.zero), width: 0, height: 0);

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _next,
        child: TweenAnimationBuilder<Rect?>(
          tween: RectTween(end: target),
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeOutCubic,
          builder: (context, rect, _) {
            final r = rect ?? target;
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SpotlightPainter(
                      hole: hole == null ? null : r,
                      radius: _step.radius,
                    ),
                  ),
                ),
                _placeCallout(size, hole == null ? null : r),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _placeCallout(Size size, Rect? hole) {
    final card = _CalloutCard(
      step: _step,
      index: _i,
      total: widget.steps.length,
      onNext: _next,
      onSkip: _close,
    );

    if (hole == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: card,
        ),
      );
    }

    // 아래에 220pt 는 있어야 카드가 잘리지 않습니다.
    final below = switch (_step.side) {
      CoachSide.below => true,
      CoachSide.above => false,
      CoachSide.auto => (size.height - hole.bottom) > 240,
    };

    final insets = MediaQuery.paddingOf(context);

    return Positioned(
      left: 20,
      right: 20,
      top: below ? math.min(hole.bottom + 18, size.height - 210) : null,
      bottom: below
          ? null
          : math.max(size.height - hole.top + 18, insets.bottom + 16),
      child: card,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 막
// ─────────────────────────────────────────────────────────────

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({required this.hole, required this.radius});

  final Rect? hole;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;

    // 순검정이 아니라 잉크에 가까운 짙은 갈색입니다. 종이 위에 검정 막을
    // 씌우면 그 순간만 다른 앱이 됩니다.
    final scrim = Paint()..color = const Color(0xE61A140C);

    final h = hole;
    if (h == null || h.width < 4 || h.height < 4) {
      canvas.drawRect(full, scrim);
      return;
    }

    final rr = RRect.fromRectAndRadius(h, Radius.circular(radius));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(full),
        Path()..addRRect(rr),
      ),
      scrim,
    );

    // 도려낸 자리의 테두리 — 황동 실선 한 가닥.
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.foil.withValues(alpha: 0.85),
    );

    // 네 귀퉁이의 크롭 마크.
    const gap = 6.0;
    const arm = 11.0;
    final tick = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AppColors.stock.withValues(alpha: 0.72);

    void mark(Offset corner, double sx, double sy) {
      final x = corner.dx - sx * gap;
      final y = corner.dy - sy * gap;
      canvas.drawLine(Offset(x - sx * arm, y), Offset(x, y), tick);
      canvas.drawLine(Offset(x, y - sy * arm), Offset(x, y), tick);
    }

    mark(h.topLeft, 1, 1);
    mark(h.topRight, -1, 1);
    mark(h.bottomLeft, 1, -1);
    mark(h.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.hole != hole || old.radius != radius;
}

// ─────────────────────────────────────────────────────────────
// 설명 카드
// ─────────────────────────────────────────────────────────────

class _CalloutCard extends StatelessWidget {
  const _CalloutCard({
    required this.step,
    required this.index,
    required this.total,
    required this.onNext,
    required this.onSkip,
  });

  final CoachStep step;
  final int index;
  final int total;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final last = index >= total - 1;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.stock,
        border: Border.all(color: AppColors.foil.withValues(alpha: 0.5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(step.eyebrow,
                  style: AppText.eyebrow(color: AppColors.foil, size: 9)),
              const Spacer(),
              Text(
                '${(index + 1).toString().padLeft(2, '0')} / '
                    '${total.toString().padLeft(2, '0')}',
                style: AppText.data(size: 9.5, color: AppColors.pulp),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(step.title,
              style:
              AppText.display(size: 19, height: 1.25, color: AppColors.ink)),
          const SizedBox(height: 8),
          Text(step.body,
              style: AppText.ui(
                  size: 12.5, height: 1.62, color: AppColors.inkSoft)),
          const SizedBox(height: 14),
          Container(height: 1, color: AppColors.line),
          const SizedBox(height: 6),
          Row(
            children: [
              // 건너뛰기는 마지막 단계에서 의미가 없습니다. 자리를 비웁니다.
              if (!last)
                _FlatButton(label: '건너뛰기', onTap: onSkip, dim: true)
              else
                const SizedBox(width: 4),
              const Spacer(),
              for (var i = 0; i < total; i++) ...[
                Container(
                  width: i == index ? 14 : 5,
                  height: 3,
                  color: i == index ? AppColors.oxblood : AppColors.line,
                ),
                const SizedBox(width: 4),
              ],
              const Spacer(),
              _FlatButton(label: last ? '알겠어요' : '다음', onTap: onNext),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlatButton extends StatelessWidget {
  const _FlatButton({
    required this.label,
    required this.onTap,
    this.dim = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          // 글자만 두면 터치 영역이 글자 크기입니다. 손가락에 안 걸립니다.
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Text(
            label,
            style: AppText.ui(
              size: 12.5,
              weight: dim ? FontWeight.w400 : FontWeight.w700,
              color: dim ? AppColors.pulp : AppColors.oxblood,
            ),
          ),
        ),
      ),
    );
  }
}