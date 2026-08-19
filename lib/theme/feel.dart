import 'package:flutter/services.dart';

/// 촉감 어휘.
///
/// 그동안 `HapticFeedback.lightImpact()` / `mediumImpact()` / `selectionClick()`이
/// 26곳에 즉흥적으로 흩어져 있었습니다. 같은 세기가 어떤 곳에서는 "골랐다",
/// 다른 곳에서는 "떼어냈다"를 뜻하니, 손끝이 그걸 언어로 배울 수가 없었습니다.
///
/// 여기서는 **동작에 이름을 붙이고** 세기를 그 이름에 묶습니다.
/// 호출부는 세기를 고르지 않고 무슨 일이 일어났는지만 말합니다.
///
/// ```dart
/// Feel.snap();     // ○  무슨 일인지 읽힘
/// HapticFeedback.selectionClick();  // ✗  왜 이 세기인지 알 수 없음
/// ```
abstract final class Feel {
  /// 전역 스위치. 설정 화면이 생기면 여기에 물리면 됩니다.
  static bool enabled = true;

  /// 눈금에 걸렸다. 각도·자리가 스냅에 들어가는 **순간에 한 번만**.
  /// 스냅에 머무는 동안 반복해서 울리면 안 됩니다.
  static void snap() => _fire(HapticFeedback.selectionClick);

  /// 목록에서 하나를 골랐다. 색, 서체, 질감 칩.
  static void pick() => _fire(HapticFeedback.selectionClick);

  /// 집어 들었다. 레이어를 끌기 시작하는 순간.
  static void lift() => _fire(HapticFeedback.lightImpact);

  /// 내려놓았다. 새 레이어를 종이에 붙이는 순간.
  static void place() => _fire(HapticFeedback.lightImpact);

  /// 도장을 찍었다. 별점, 확정 버튼.
  static void stamp() => _fire(HapticFeedback.mediumImpact);

  /// 뜯어냈다. 레이어 삭제, 티켓 삭제.
  static void tear() => _fire(HapticFeedback.mediumImpact);

  /// 닫혔다 / 눌러 찍혔다. 서류철 저장, 되돌릴 수 없는 확정.
  static void shut() => _fire(HapticFeedback.heavyImpact);

  static void _fire(Future<void> Function() f) {
    if (!enabled) return;
    f();
  }
}