import 'package:flutter/foundation.dart';

import '../data/local_store.dart';

/// 앱 안내를 **한 번만** 보여주기 위한 표시들.
///
/// ## 왜 별도 서비스인가
///
/// "본 적 있나?"는 티켓 데이터가 아닙니다. [TicketStore]에 끼워 넣으면
/// 동기화 대상(`SyncService`의 해시 그림자)에 섞여 들어가고, 서버에
/// `guide_seen: true` 같은 행이 생깁니다. 안내를 봤는지는 **기기의 사정**이지
/// 계정의 기록이 아닙니다.
///
/// 그래서 [LocalStore]에 작은 맵 하나로만 남깁니다.
/// (탈퇴하면 `LocalStore.wipe()`가 같이 지웁니다)
///
/// ## 언제 초기화되나
///
/// * **가입 직후** — 새 계정은 새 사람입니다. 한 기기를 나눠 쓰는 경우
///   앞사람이 안내를 봤다고 뒷사람이 건너뛰면 안 됩니다.
///   ([AuthService.signUp]이 [reset]을 부릅니다)
/// * **설정 → 앱 안내 다시 보기** — 사용자가 직접.
///
/// 로그아웃에서는 지우지 않습니다. 같은 사람이 다시 들어오는 것뿐입니다.
class GuideService extends ChangeNotifier {
  GuideService._();

  static final GuideService instance = GuideService._();

  final _local = LocalStore.instance;

  /// 첫 화면 안내(투어)를 봤다.
  static const _kTour = 'tour';

  /// 서랍 화면의 코치 마크를 봤다.
  static const _kDrawer = 'drawer';

  final Map<String, bool> _flags = {};

  bool _loaded = false;

  bool get isLoaded => _loaded;

  /// `AppGate._boot()`에서 한 번. 실패해도 앱은 떠야 하므로 던지지 않습니다.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final j = await _local.readMap(LocalStore.kGuide);
      j?.forEach((k, v) {
        if (v is bool) _flags[k] = v;
      });
    } catch (_) {
      // 못 읽으면 "아직 안 봤다"로 봅니다. 한 번 더 보는 편이
      // 영영 못 보는 것보다 낫습니다.
    }
    _loaded = true;
  }

  bool get sawTour => _flags[_kTour] ?? false;

  bool get sawDrawerCoach => _flags[_kDrawer] ?? false;

  /// 아직 아무 안내도 못 본 상태. 빈 서랍 문구를 고를 때 씁니다.
  bool get isFirstRun => !sawTour;

  Future<void> markTourSeen() => _set(_kTour, true);

  Future<void> markDrawerCoachSeen() => _set(_kDrawer, true);

  /// 처음부터 다시. 가입 직후·"다시 보기"에서 부릅니다.
  Future<void> reset() async {
    if (_flags.isEmpty) {
      _loaded = true;
      notifyListeners();
      return;
    }
    _flags.clear();
    _loaded = true;
    try {
      await _local.delete(LocalStore.kGuide);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _set(String key, bool value) async {
    if (_flags[key] == value) return;
    _flags[key] = value;
    notifyListeners();
    try {
      await _local.write(LocalStore.kGuide, _flags);
    } catch (_) {
      // 저장에 실패해도 이번 실행에서는 다시 뜨지 않습니다.
      // (다음 실행에서 한 번 더 보게 될 뿐입니다)
    }
  }
}