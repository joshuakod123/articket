import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 서류철이 열리는 화면 전환.
///
/// 누른 서류철 자리에서 표지가 위로 젖혀 열리고, 그 아래에서
/// 폴더 내용물(스크랩북)이 차오르며 화면을 채웁니다.
/// 뒤로 갈 때는 반대로 표지가 다시 덮입니다.
class FolderOpenRoute<T> extends PageRoute<T> {
  FolderOpenRoute({
    required this.builder,
    required this.originRect,
    required this.cover,
  });

  final WidgetBuilder builder;

  /// 누른 서류철의 화면 좌표(전역).
  final Rect originRect;

  /// 젖혀 열릴 표지 복제본.
  final Widget cover;

  @override
  bool get opaque => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 560);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 420);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) =>
      builder(context);

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    // 모션 축소 설정을 켠 사용자는 페이드만.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return FadeTransition(opacity: animation, child: child);
    }

    final t = Curves.easeInOutCubic.transform(animation.value);
    final size = MediaQuery.sizeOf(context);

    // 표지 자리가 화면 전체로 번져 나갑니다.
    final rect = Rect.lerp(
      originRect,
      Offset.zero & size,
      Curves.easeOutCubic.transform((t * 1.25).clamp(0.0, 1.0)),
    )!;

    // 표지가 위쪽 접힌 선을 축으로 젖혀지는 각도.
    final open = (t / 0.9).clamp(0.0, 1.0) * math.pi * 0.62;

    // 표지는 후반부에 빛에 씻기듯 사라집니다.
    final coverFade = 1.0 - ((t - 0.62) / 0.38).clamp(0.0, 1.0);

    return Stack(
      children: [
        // 내용물. 서류철 안에서 꺼내지듯 아주 살짝 커지며 차오릅니다.
        Opacity(
          opacity: ((t - 0.18) / 0.5).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.965 + 0.035 * t,
            child: child,
          ),
        ),

        // 젖혀 열리는 표지.
        if (coverFade > 0)
          Positioned.fromRect(
            rect: rect,
            child: IgnorePointer(
              child: Opacity(
                opacity: coverFade,
                child: Transform(
                  alignment: Alignment.topCenter,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0009)
                    ..rotateX(open),
                  child: cover,
                ),
              ),
            ),
          ),
      ],
    );
  }
}