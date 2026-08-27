import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 기기 안에 남는 값을 한 군데로 모은 얇은 껍데기.
///
/// ## 왜 만들었나
///
/// [TicketStore]가 인메모리였습니다. `mockTickets`를 생성자에서 부어 넣고,
/// 사용자가 만든 티켓은 앱을 끄면 사라졌습니다. 화면을 다 만들 때까지는
/// 그걸로 충분했지만 이제는 두 가지 이유로 진짜 저장이 필요합니다.
///
/// 1. 사용자가 만든 티켓이 남아야 합니다. (당연한 얘기)
/// 2. **탈퇴할 때 지울 것이 있어야 합니다.** 남는 게 없으면 "영구 삭제"라는
///    약속을 지켰는지 확인할 방법도 없습니다.
///
/// SharedPreferences 를 쓴 이유는 지금 데이터가 작기 때문입니다(티켓 수십 장).
/// 스키마가 커지면 이 파일의 [read] · [write] 두 메서드만 Hive/Isar 호출로
/// 바꾸면 됩니다. 바깥에서는 이 클래스만 보고 있으니까요.
class LocalStore {
  LocalStore._();

  static final LocalStore instance = LocalStore._();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// 키를 문자열로 흩뿌리지 않고 여기에 모아 둡니다.
  /// 탈퇴에서 "전부 지우기"를 할 때 빠뜨리는 키가 없도록.
  static const kTickets = 'articket.tickets.v2';
  static const kFolders = 'articket.folders.v2';
  static const kIssued = 'articket.issued.v2';
  static const kSeeded = 'articket.seeded.v2';
  static const kViewerName = 'articket.viewer.name';
  static const kAccount = 'articket.account.v1';
  static const kSession = 'articket.session.v1';
  static const kPrefs = 'articket.prefs.v1';

  /// 앱 안내를 봤는지. 기기의 사정이라 계정과 함께 지우지 않습니다.
  static const kGuide = 'articket.guide.v1';

  /// 구버전이 깔아 둔 **예시 데이터를 걷어냈는지**. 한 번만 돕니다.
  /// (`TicketStore._purgeLegacySample` 참고)
  static const kSamplePurged = 'articket.sample.purged.v1';

  /// **기록**에 해당하는 키. 계정을 갈아탈 때 이만큼만 비웁니다.
  ///
  /// 계정 캐시([kAccount])와 세션([kSession])이 여기 없는 것이 핵심입니다.
  /// 예전에는 [TicketStore.wipe] 가 [wipe] 를 불러 **방금 로그인한 계정
  /// 정보까지** 지웠습니다. 그래서 계정을 갈아타면 회원 번호가 사라지고
  /// 다음에 로그인 화면에서 이메일 자동 채우기도 먹통이 됐습니다.
  static const dataKeys = <String>[
    kTickets,
    kFolders,
    kIssued,
    kSeeded,
    kViewerName,
    kSamplePurged,
  ];

  static const allKeys = <String>[
    ...dataKeys,
    kAccount,
    kSession,
    kPrefs,
    kGuide,
  ];

  Future<Map<String, dynamic>?> readMap(String key) async {
    final raw = (await _p).getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      // 깨진 값은 조용히 버립니다. 앱이 못 켜지는 것보다 낫습니다.
      return null;
    }
  }

  Future<List<dynamic>?> readList(String key) async {
    final raw = (await _p).getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, Object value) async =>
      (await _p).setString(key, jsonEncode(value));

  Future<String?> readString(String key) async => (await _p).getString(key);

  Future<void> writeString(String key, String value) async =>
      (await _p).setString(key, value);

  Future<bool> readFlag(String key) async => (await _p).getBool(key) ?? false;

  Future<void> writeFlag(String key, bool value) async =>
      (await _p).setBool(key, value);

  Future<void> delete(String key) async => (await _p).remove(key);

  /// 탈퇴에서 씁니다. 이 앱이 기기에 남긴 것을 **전부** 지웁니다.
  ///
  /// `clear()` 대신 키를 하나씩 지우는 이유: 같은 번들 안에 다른 플러그인이
  /// 써 둔 값(예: 이미지 캐시 경로)까지 날리지 않기 위해서입니다.
  Future<void> wipe() async {
    final p = await _p;
    for (final k in allKeys) {
      await p.remove(k);
    }
  }

  /// **기록만** 지웁니다. 계정·세션·설정은 그대로 둡니다.
  ///
  /// 계정 전환·가입 직후에 씁니다. 그 순간 사용자는 로그인한 상태이고,
  /// 지워야 하는 것은 앞사람의 티켓이지 방금 발급받은 세션이 아닙니다.
  Future<void> wipeData() async {
    final p = await _p;
    for (final k in dataKeys) {
      await p.remove(k);
    }
  }
}