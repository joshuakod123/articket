import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// 손에서 놓은 종이가 미끄러져 멎는 물리.
///
/// ## 왜 스프링을 여기서만 쓰나
///
/// "등장 애니메이션을 스프링으로 바꾸면 고급스러워진다"는 조언을 흔히 듣는데,
/// 이 앱에서는 **틀린 조언입니다.** 종이는 튀지 않습니다. 무겁고 감쇠가 큽니다.
/// 오버슛이 있는 스프링은 젤리의 물성이지 보관용 서류의 물성이 아닙니다.
/// 화면에 그냥 나타나는 요소는 기존 `easeOutCubic` 이 재질에 더 맞습니다.
///
/// 스프링이 옳은 자리는 **사용자의 손가락 속도를 애니메이션이 이어받는 순간**
/// 하나뿐입니다. 스티커를 튕겨 놓았을 때, 티켓을 던졌을 때. 그 순간 속도가
/// 뚝 끊기면 손과 화면이 분리된 느낌이 납니다.
///
/// 그래서 [paper]는 **거의 과감쇠**로 잡았습니다. 되튀지 않고, 무게만 남습니다.
class PaperSpring {
  PaperSpring._();

  /// 종이의 물성. damping을 임계값 근처까지 올려 되튐을 없앴습니다.
  ///
  /// 임계 감쇠 계수는 `2 * sqrt(stiffness * mass)` ≈ 2 * sqrt(380) ≈ 39.
  /// 34는 그보다 살짝 낮아, 눈에 안 보일 만큼만 무르게 멎습니다.
  static const SpringDescription paper = SpringDescription(
    mass: 1,
    stiffness: 380,
    damping: 34,
  );
}

/// 놓은 자리에서 속도를 이어받아 멎게 하는 작은 헬퍼.
///
/// 가로/세로를 각각 독립된 무제한 컨트롤러로 굴립니다.
/// 값은 캔버스 대비 0.0~1.0 비율이라, 속도도 비율/초로 바꿔 넘겨야 합니다.
///
/// ```dart
/// _settle = SpringSettle(vsync: this);   // State 에서 한 번
/// ...
/// onEnd: (details) {
///   _settle.fling(
///     from: Offset(t.px!, t.py!),
///     velocity: Offset(
///       details.velocity.pixelsPerSecond.dx / canvas.width,
///       details.velocity.pixelsPerSecond.dy / canvas.height,
///     ),
///     bounds: const Rect.fromLTRB(0.05, 0.05, 0.95, 0.95),
///     onUpdate: (p) => setState(() { t.px = p.dx; t.py = p.dy; }),
///     onSettled: _endGesture,
///   );
/// }
/// ```
class SpringSettle {
  SpringSettle({required TickerProvider vsync})
      : _x = AnimationController.unbounded(vsync: vsync),
        _y = AnimationController.unbounded(vsync: vsync);

  final AnimationController _x;
  final AnimationController _y;

  /// 던진 거리를 얼마나 이어받을지. 1초치 속도를 그대로 쓰면 너무 멀리 갑니다.
  static const double _carry = 0.16;

  /// 이 속도보다 느리면 그냥 제자리입니다. 손을 가만히 뗀 것까지
  /// 애니메이션으로 처리하면 오히려 미끄러지는 느낌이 납니다.
  static const double _threshold = 0.25;

  bool get isRunning => _x.isAnimating || _y.isAnimating;

  /// 이번 fling 에 붙인 리스너. 떼어낼 때 필요해서 들고 있습니다.
  ///
  /// 예전에는 `AnimationController.clearListeners()` 를 불렀는데, 그건
  /// `AnimationLocalListenersMixin` 의 `@protected` 멤버라 바깥에서 부르면
  /// 안 됩니다(analyzer: invalid_use_of_protected_member). 게다가 **누가
  /// 붙였든 전부** 지워버려서, 나중에 같은 컨트롤러를 다른 곳에서 듣게 되면
  /// 조용히 끊깁니다. 내가 붙인 것만 정확히 뗍니다.
  VoidCallback? _onX;
  VoidCallback? _onY;

  /// 몇 번째 fling 인지. `whenCompleteOrCancel` 은 마이크로태스크로 늦게
  /// 오기 때문에, 새 fling 이 시작되면서 취소된 **옛 fling 의 뒷정리**가
  /// 방금 붙인 새 리스너를 떼어가는 일이 생깁니다. 세대가 다르면 무시합니다.
  int _generation = 0;

  void fling({
    required Offset from,
    required Offset velocity,
    required Rect bounds,
    required void Function(Offset) onUpdate,
    void Function()? onSettled,
  }) {
    stop();

    if (velocity.distance < _threshold) {
      onSettled?.call();
      return;
    }

    final target = Offset(
      (from.dx + velocity.dx * _carry).clamp(bounds.left, bounds.right),
      (from.dy + velocity.dy * _carry).clamp(bounds.top, bounds.bottom),
    );

    final generation = ++_generation;

    var current = from;
    void push() => onUpdate(current);

    _onX = () {
      current = Offset(_x.value.clamp(bounds.left, bounds.right), current.dy);
      push();
    };
    _onY = () {
      current = Offset(current.dx, _y.value.clamp(bounds.top, bounds.bottom));
      push();
    };

    _x
      ..value = from.dx
      ..addListener(_onX!);

    _y
      ..value = from.dy
      ..addListener(_onY!);

    _x.animateWith(
      SpringSimulation(PaperSpring.paper, from.dx, target.dx, velocity.dx),
    );

    _y
        .animateWith(
      SpringSimulation(PaperSpring.paper, from.dy, target.dy, velocity.dy),
    )
        .whenCompleteOrCancel(() {
      if (generation != _generation) return;
      _clearListeners();
      onSettled?.call();
    });
  }

  void stop() {
    _x.stop();
    _y.stop();
    _clearListeners();
  }

  void _clearListeners() {
    if (_onX != null) {
      _x.removeListener(_onX!);
      _onX = null;
    }
    if (_onY != null) {
      _y.removeListener(_onY!);
      _onY = null;
    }
  }

  void dispose() {
    _clearListeners();
    _x.dispose();
    _y.dispose();
  }
}