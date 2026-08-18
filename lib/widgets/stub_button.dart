import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'paper.dart';

/// 빈 티켓 한 장의 실루엣. 좌우에 반원 타공, 왼쪽 1/3 지점에 절취선.
class _StubShape extends CustomClipper<Path> {
  const _StubShape();

  /// 모서리 라운드.
  static const radius = 4.0;

  /// 좌우 반원 타공의 반지름.
  static const notch = 7.0;

  @override
  Path getClip(Size size) {
    final body = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(radius),
      ));

    final x = size.width * 0.30;
    final holes = Path()
      ..addOval(Rect.fromCircle(center: Offset(x, 0), radius: notch))
      ..addOval(Rect.fromCircle(center: Offset(x, size.height), radius: notch));

    return Path.combine(PathOperation.difference, body, holes);
  }

  @override
  bool shouldReclip(_StubShape old) => false;
}

/// 절취선 점선 한 줄.
class _TearLinePainter extends CustomPainter {
  _TearLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;

    const dash = 2.5;
    const gap = 3.5;
    for (double y = 7; y < size.height - 7; y += dash + gap) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, y + dash),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_TearLinePainter old) => false;
}

/// "티켓 만들기" — 발권기에서 뽑혀 나온 빈 티켓 한 장.
///
/// 머티리얼 FAB의 둥근 알약 대신, 앱 안의 다른 모든 것과 같은 **인쇄물**로
/// 만들었습니다. 좌우 타공과 절취선이 있어 누르기 전부터 티켓처럼 보입니다.
/// 누르면 살짝 눌렸다 튀어오르며 발권되는 촉감을 냅니다.
class TicketStubButton extends StatefulWidget {
  const TicketStubButton({
    super.key,
    required this.onPressed,
    this.label = '티켓 만들기',
    this.code = 'NEW',
    this.width = 210,
    this.height = 52,
  });

  final VoidCallback onPressed;
  final String label;

  /// 왼쪽 절취 조각에 찍히는 짧은 코드.
  final String code;
  final double width;
  final double height;

  @override
  State<TicketStubButton> createState() => _TicketStubButtonState();
}

class _TicketStubButtonState extends State<TicketStubButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 130),
    reverseDuration: const Duration(milliseconds: 220),
  );

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _fire() {
    HapticFeedback.lightImpact();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => _press.forward(),
        onTapUp: (_) {
          _press.reverse();
          _fire();
        },
        onTapCancel: _press.reverse,
        child: AnimatedBuilder(
          animation: _press,
          builder: (context, child) {
            final t = Curves.easeOut.transform(_press.value);
            return Transform.translate(
              offset: Offset(0, 2 * t),
              child: Transform.scale(scale: 1 - 0.02 * t, child: child),
            );
          },
          child: DecoratedBox(
            decoration: BoxDecoration(boxShadow: paperShadow(depth: 0.5)),
            child: ClipPath(
              clipper: const _StubShape(),
              child: SizedBox(
                width: widget.width,
                height: widget.height,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: const PaperSurface(
                        color: AppColors.oxblood,
                        grain: 0.10,
                        seed: 77,
                        fiber: 0.8,
                        child: SizedBox.expand(),
                      ),
                    ),

                    // 위쪽에서 빛이 스치는 결.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.13),
                                Colors.white.withValues(alpha: 0.0),
                                Colors.black.withValues(alpha: 0.10),
                              ],
                              stops: const [0.0, 0.45, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 절취선.
                    Positioned(
                      left: widget.width * 0.30 - 4,
                      top: 0,
                      bottom: 0,
                      width: 8,
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _TearLinePainter(
                            color: AppColors.stockLight.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    ),

                    // 내용.
                    Row(
                      children: [
                        SizedBox(
                          width: widget.width * 0.30,
                          child: Center(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: Text(
                                widget.code,
                                maxLines: 1,
                                style: AppText.data(
                                  size: 9,
                                  spacing: 2.2,
                                  weight: FontWeight.w700,
                                  color: AppColors.stockLight
                                      .withValues(alpha: 0.75),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add,
                                  size: 16,
                                  color: AppColors.stockLight
                                      .withValues(alpha: 0.9),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    widget.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.ui(
                                      size: 14,
                                      weight: FontWeight.w600,
                                      color: AppColors.stockLight,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 화면 아래에 고정으로 깔리는 발권 레일.
///
/// FAB처럼 콘텐츠 위를 떠다니며 스크랩북 모서리를 가리는 대신,
/// **바닥에 붙은 종이 띠** 위에 티켓을 가운데로 얹었습니다.
/// 위치가 고정이라 어느 화면 크기에서도 어색해지지 않습니다.
class NewTicketRail extends StatelessWidget {
  const NewTicketRail({
    super.key,
    required this.onPressed,
    this.hint,
    this.code = 'NEW',
  });

  final VoidCallback onPressed;

  /// 버튼 아래에 작게 찍히는 안내. 없으면 생략합니다.
  final String? hint;
  final String code;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.stock,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Stack(
        children: [
          const WallGrain(opacity: 0.05, seed: 21),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TicketStubButton(onPressed: onPressed, code: code),
                  if (hint != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      hint!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.data(
                          size: 9, spacing: 1.2, color: AppColors.pulp),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}