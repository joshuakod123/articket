import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/layer.dart';
import '../models/ticket.dart';
import '../services/auth_service.dart';
import '../services/poster_storage.dart';
import 'local_store.dart';
import 'mock_data.dart';
import 'remote_store.dart';
import 'serial.dart';
import 'sync_service.dart';

/// 티켓·서류철 저장소.
///
/// ## 세 번째로 바뀐 것 — 서버가 붙었습니다
///
/// **화면에서 보면 달라진 게 없습니다.** 여전히 이 객체 하나만 구독하면 되고,
/// 서버는 [SyncService]가 옆에서 붙습니다. 서랍을 여는 데 네트워크가 필요하지
/// 않다는 게 이 앱의 전제이므로, 읽기 경로는 그대로 메모리 → SharedPreferences
/// 입니다.
///
/// 실제로 늘어난 것은 셋뿐입니다.
///
/// 1. [_changed] 에 `SyncService.noteChange()` **한 줄**. 이 앱의 모든 수정이
///    이 함수를 지나므로 여기 한 줄이면 전부 잡힙니다.
/// 2. 동기화가 받아온 것을 반영할 `*Quiet` 메서드 넷. 알림도 저장도 하지
///    않습니다 — 받아온 것을 다시 "바뀌었다"고 표시하면 서버로 되돌려 올리는
///    무한 루프가 돕니다.
/// 3. 발권 번호를 서버에서 받아옵니다([add] 문서 참고).
class TicketStore extends ChangeNotifier {
  TicketStore._();

  static final TicketStore instance = TicketStore._();

  final _local = LocalStore.instance;

  final List<ArchiveFolder> _folders = [];
  final List<Ticket> _tickets = [];

  /// 연도별로 **지금까지 찍은 가장 큰 번호**. 다음 번호는 여기에 +1 입니다.
  ///
  /// 서버가 붙은 뒤로는 **로그인 전 / 오프라인 폴백**에만 쓰입니다. 로그인
  /// 상태에서는 서버 `ticket_counters` 가 진짜 대장입니다.
  final Map<int, int> _issued = {};

  bool _ready = false;

  /// [load]가 끝났는지. 스플래시가 이 값을 봅니다.
  bool get isReady => _ready;

  List<ArchiveFolder> get folders => List.unmodifiable(_folders);

  List<Ticket> get tickets => List.unmodifiable(_tickets);

  // ── 불러오기 / 저장하기 ──────────────────────────

  /// 앱을 켤 때 한 번. 스플래시에서 기다립니다.
  Future<void> load() async {
    if (_ready) return;

    final folderJson = await _local.readList(LocalStore.kFolders);
    final ticketJson = await _local.readList(LocalStore.kTickets);
    final issuedJson = await _local.readMap(LocalStore.kIssued);
    final seeded = await _local.readFlag(LocalStore.kSeeded);

    if (folderJson != null) {
      for (final j in folderJson) {
        try {
          _folders.add(ArchiveFolder.fromJson(j as Map<String, dynamic>));
        } catch (_) {
          // 한 장이 깨졌다고 나머지를 못 읽을 이유는 없습니다.
        }
      }
    }
    if (ticketJson != null) {
      for (final j in ticketJson) {
        try {
          _tickets.add(Ticket.fromJson(j as Map<String, dynamic>));
        } catch (_) {}
      }
    }
    if (issuedJson != null) {
      issuedJson.forEach((k, v) {
        final year = int.tryParse(k);
        if (year != null && v is int) _issued[year] = v;
      });
    }

    // ⚠️ **예시 데이터를 더 이상 깔지 않습니다.**
    //
    // 예전에는 여기서 `mockFolders` · `mockTickets` 를 부어 넣었습니다.
    // 화면을 만드는 동안에는 편했지만, 서버가 붙은 뒤로는 이런 일이
    // 벌어졌습니다.
    //
    //   1. 앱을 처음 켬        → 이 기기에 예시 6장이 깔림
    //   2. 새 사용자가 가입     → `adoptLocalDataThenSync()` 가 그 6장을
    //                            **새 계정의 기록으로 서버에 올림**
    //   3. 사용자가 본 첫 화면  → 가본 적 없는 모네·고흐 전시가 든 서랍
    //
    // 남의 기억을 자기 서랍에서 발견하는 셈입니다. 게다가 그걸 지우려면
    // 여섯 번을 지워야 합니다. 빈 서랍이 훨씬 정직합니다. 대신 빈 서랍
    // 화면과 첫 안내(`GuideService`)가 다음에 무엇을 할지 알려줍니다.
    //
    // `seeded` 는 아래 [_purgeLegacySample] 이 "이 기기에 예시가 깔린 적이
    // 있는가"를 판단하는 데만 씁니다.
    await _purgeLegacySample(hadSeed: seeded);

    // 구버전에서 올라온, 아직 번호가 없는 티켓에 지금 도장을 찍습니다.
    // 이렇게 찍힌 번호는 첫 동기화에서 `raise_ticket_counter` 가 서버 카운터로
    // 끌어올립니다. 그래야 서버가 1번부터 발급해 충돌하는 일이 없습니다.
    _issueMissing();
    _syncIssuedFloor();

    _ready = true;
    await _persist();
    notifyListeners();
  }

  /// 구버전이 이 기기에 깔아 둔 예시를 **한 번만** 걷어냅니다.
  ///
  /// 새로 설치한 기기에는 애초에 예시가 없으니 할 일이 없습니다. 문제는 이미
  /// 예시를 받은 채로 쓰고 있던 기기입니다. 그냥 두면 업데이트 뒤에도 남의
  /// 전시가 서랍에 그대로 있습니다.
  ///
  /// ## 지우는 기준을 좁게 잡았습니다
  ///
  /// * 티켓은 **예시 id 여섯 개**만 지웁니다.
  /// * 서류철은 예시 id 다섯 개 중 **안이 빈 것만** 지웁니다.
  ///
  /// 사용자가 `2026 ARCHIVE` 안에 자기 티켓을 철해 뒀을 수 있습니다. 그
  /// 서류철까지 지우면 사용자가 만든 기록이 같이 날아갑니다. 예시를 치우려다
  /// 진짜 기록을 지우는 것보다는, 이름만 예시인 빈 서류철이 하나 남는 편이
  /// 훨씬 낫습니다(그건 사용자가 직접 지울 수 있습니다).
  ///
  /// 지워진 것은 다음 동기화에서 서버에도 묘비가 세워집니다.
  /// `SyncService._rescan()` 이 "그림자에는 있는데 목록에 없는 id"로 잡아냅니다.
  Future<void> _purgeLegacySample({required bool hadSeed}) async {
    if (await _local.readFlag(LocalStore.kSamplePurged)) return;
    await _local.writeFlag(LocalStore.kSamplePurged, true);

    // 예시가 깔린 적이 없는 기기라면 여기서 끝입니다.
    if (!hadSeed) return;

    _tickets.removeWhere((t) => kSampleTicketIds.contains(t.id));
    _folders.removeWhere((f) =>
    kSampleFolderIds.contains(f.id) &&
        !_tickets.any((t) => t.folderId == f.id));

    await _local.writeFlag(LocalStore.kSeeded, false);
  }

  /// **테스트·데모 전용.** 예시 데이터를 손으로 부어 넣습니다.
  ///
  /// 앱 실행 경로에서는 절대 부르지 않습니다. `test/widget_test.dart` 처럼
  /// "서류철이 여러 장 있는 상태"가 필요한 자리에서만 씁니다.
  @visibleForTesting
  void seedSampleData() {
    _folders.addAll(mockFolders);
    _tickets.addAll(mockTickets);
    _issueMissing();
    _syncIssuedFloor();
    notifyListeners();
  }

  /// 발권 도장이 없는 티켓(구버전 데이터 · 예시)에 관람일 순서대로 찍습니다.
  void _issueMissing() {
    final pending = _tickets.where((t) => !t.isIssued).toList()
      ..sort((a, b) {
        final d = a.visitedAt.compareTo(b.visitedAt);
        return d != 0 ? d : a.id.compareTo(b.id);
      });
    for (final t in pending) {
      _stamp(t);
    }
  }

  /// 저장된 최고값이 실제 티켓의 번호보다 낮으면 끌어올립니다.
  /// (예전 버전에서 넘어온 데이터에 대비한 안전장치)
  void _syncIssuedFloor() {
    for (final t in _tickets) {
      if (!t.isIssued) continue;
      final cur = _issued[t.issuedYear] ?? 0;
      if (t.issuedSeq > cur) _issued[t.issuedYear] = t.issuedSeq;
    }
  }

  Future<void> _persist() async {
    if (!_ready) return;
    await _local.write(
        LocalStore.kFolders, _folders.map((f) => f.toJson()).toList());
    await _local.write(
        LocalStore.kTickets, _tickets.map((t) => t.toJson()).toList());
    await _local.write(
        LocalStore.kIssued, _issued.map((k, v) => MapEntry('$k', v)));
  }

  /// 값이 바뀔 때마다 부르는 한 줄. 저장은 기다리지 않습니다(화면을 붙잡지 않게).
  void _changed() {
    notifyListeners();
    unawaited(_persist());
    // ↓ 서버가 붙으면서 늘어난 한 줄. 이 앱의 모든 수정이 여기를 지납니다.
    //   무엇이 바뀌었는지는 SyncService 가 내용 해시로 알아냅니다.
    SyncService.instance.noteChange();
  }

  /// 탈퇴·계정 전환에서 씁니다. 메모리와 기기 양쪽을 비웁니다.
  ///
  /// ⚠ **[SyncService.reset] 이 반드시 먼저입니다.** 리스트를 먼저 비우면
  /// [_changed] → `noteChange()` 가 "티켓이 전부 사라졌다"고 읽고 **서버
  /// 전체에 묘비를 세웁니다.** 로그아웃하려던 사용자의 기록이 서버에서도
  /// 지워집니다. 여기서 순서를 지키므로 호출부는 신경 쓰지 않아도 됩니다.
  /// ⚠ **두 번째 함정 — `_ready` 를 내리면 안 됩니다.**
  ///
  /// 예전에는 여기서 `_ready = false` 로 두었습니다. 그런데 [load] 는
  /// `if (_ready) return;` 으로 시작하는 **부팅 전용** 메서드라, 앱을 껐다
  /// 켜기 전에는 아무도 이 값을 다시 올려주지 않았습니다. 결과는 조용한
  /// 데이터 유실입니다.
  ///
  ///   계정 삭제 · 계정 전환
  ///     → `_ready = false`
  ///     → [_persist] 가 첫 줄에서 되돌아감          → **아무것도 저장 안 됨**
  ///     → `SyncService.noteChange()` 도 `isReady` 를 보고 되돌아감
  ///                                                 → **아무것도 동기화 안 됨**
  ///
  /// 그 상태로 만든 티켓은 앱을 끄는 순간 사라졌습니다. 비운 뒤에도 저장소는
  /// **비어 있는 채로 준비된 상태**입니다. 그게 사실에 맞습니다.
  ///
  /// 세 번째로, [LocalStore.wipe] 대신 [LocalStore.wipeData] 를 부릅니다.
  /// 계정 전환 흐름에서는 이 호출 **직전에** 새 계정 정보가 저장되는데,
  /// 예전 코드는 그걸 방금 지워버렸습니다.
  Future<void> wipe() async {
    await SyncService.instance.reset();
    await PosterStorage.instance.wipeLocal();

    _tickets.clear();
    _folders.clear();
    _issued.clear();
    await _local.wipeData();
    notifyListeners();
  }

  // ── 조회 ────────────────────────────────────────

  List<Ticket> ticketsIn(String folderId) {
    final list = _tickets.where((t) => t.folderId == folderId).toList()
      ..sort((a, b) => b.visitedAt.compareTo(a.visitedAt));
    return list;
  }

  int countIn(String folderId) =>
      _tickets.where((t) => t.folderId == folderId).length;

  Ticket? byId(String id) {
    for (final t in _tickets) {
      if (t.id == id) return t;
    }
    return null;
  }

  ArchiveFolder? folderById(String id) {
    for (final f in _folders) {
      if (f.id == id) return f;
    }
    return null;
  }

  // ── 서류철 관리 ─────────────────────────────────

  void addFolder(ArchiveFolder folder) {
    _folders.add(folder);
    _changed();
  }

  /// 서류철을 버립니다. 안에 철해둔 티켓도 함께 사라집니다.
  ///
  /// 번호는 회수하지 않습니다. 그 번호는 이미 발권된 것으로 남습니다.
  void removeFolder(String id) {
    _folders.removeWhere((f) => f.id == id);
    _tickets.removeWhere((t) => t.folderId == id);
    _changed();
  }

  // ── 티켓 관리 ───────────────────────────────────

  /// 티켓을 철합니다.
  ///
  /// ## 번호가 서버에서 옵니다
  ///
  /// 예전 규칙은 "그 해의 최고값 + 1"이었고, 최고값은 **그 기기가 아는
  /// 최고값**이었습니다. 폰과 태블릿이 둘 다 비행기 모드에서 2026년 티켓을
  /// 만들면 둘 다 `AK-2026-005` 를 찍습니다. 그리고 "한 번 찍힌 번호는 바뀌지
  /// 않는다"가 규칙이라 나중에 어느 한쪽을 밀어줄 수도 없습니다. 규칙 둘이
  /// 서로 모순입니다.
  ///
  /// 그래서 번호는 서버가 뽑습니다. 티켓은 **즉시** 목록에 들어가고, 번호만
  /// 잠시 뒤 붙습니다. 실물도 그렇습니다 — 예매는 지금, 표는 창구에서.
  ///
  /// 오프라인이면 `AK-0000-000`(미발권)으로 남았다가 첫 동기화에서 받습니다.
  void add(Ticket ticket) {
    _tickets.add(ticket);
    _changed();
    if (!ticket.isIssued) unawaited(_stampFromServer(ticket));
  }

  Future<void> _stampFromServer(Ticket t) async {
    // 로그인 전이면 예전 규칙 그대로. 가입하면 그 번호를 서버 카운터가
    // 넘겨받습니다(SyncService._push 0단계).
    if (!AuthService.instance.isSignedIn) {
      _stamp(t);
      _changed();
      return;
    }

    final seq = await RemoteStore.issueSerial(t.visitedAt.year);
    if (seq == null) return; // 오프라인. SyncService._push 가 나중에 찍습니다

    t.issuedYear = t.visitedAt.year;
    t.issuedSeq = seq;
    final cur = _issued[t.issuedYear] ?? 0;
    if (seq > cur) _issued[t.issuedYear] = seq;
    _changed();
  }

  void remove(String id) {
    _tickets.removeWhere((t) => t.id == id);
    _changed();
  }

  /// 티켓 내용을 바꾼 뒤 호출합니다.
  ///
  /// 예전에는 여기서 번호를 다시 매겼습니다. 이제 하지 않습니다.
  /// 관람일을 고쳐도 이미 찍힌 번호는 그대로입니다.
  void touch() => _changed();

  // ── 동기화 전용 (SyncService 만 부릅니다) ─────────
  //
  // 알림도 저장도 여기서 하지 않습니다. 받아온 것을 다시 "바뀌었다"고
  // 표시하면 서버로 되돌려 올리는 루프가 돕니다. SyncService 가 한 배치를
  // 다 반영한 뒤 [touch] 를 한 번 부릅니다.

  void upsertQuiet(Ticket t) {
    final i = _tickets.indexWhere((x) => x.id == t.id);
    if (i < 0) {
      _tickets.add(t);
    } else {
      _tickets[i] = t;
    }
    if (t.isIssued) {
      final cur = _issued[t.issuedYear] ?? 0;
      if (t.issuedSeq > cur) _issued[t.issuedYear] = t.issuedSeq;
    }
  }

  void removeQuiet(String id) => _tickets.removeWhere((t) => t.id == id);

  void upsertFolderQuiet(ArchiveFolder f) {
    final i = _folders.indexWhere((x) => x.id == f.id);
    if (i < 0) {
      _folders.add(f);
    } else {
      _folders[i] = f;
    }
  }

  /// 서류철만 지웁니다. **안의 티켓은 건드리지 않습니다.**
  ///
  /// [removeFolder] 와 다른 점입니다. 티켓 쪽 묘비는 서버가 따로 보내옵니다.
  /// 여기서 같이 지우면, 아직 안 지워진 티켓까지 이 기기에서 사라지고 다음
  /// pull 이 그걸 되살립니다(깜빡임).
  void removeFolderQuiet(String id) => _folders.removeWhere((f) => f.id == id);

  // ── 발권 (로컬 폴백) ─────────────────────────────

  /// 다음 번호를 뽑아 티켓에 찍습니다. **로그인 전 · 구버전 이관 전용입니다.**
  ///
  /// 연도는 **관람한 해**, 순번은 그 해에 지금까지 찍은 최고값 + 1.
  /// 지운 번호를 되쓰지 않으므로 목록에 빈 번호가 생길 수 있습니다.
  void _stamp(Ticket t) {
    final year = t.visitedAt.year;
    final next = (_issued[year] ?? 0) + 1;
    _issued[year] = next;
    t.issuedYear = year;
    t.issuedSeq = next;
  }

  /// 다음에 찍힐 번호 **미리보기**. 에디터에서 보여주는 값입니다.
  ///
  /// 서버가 붙은 뒤로는 말 그대로 미리보기입니다 — 다른 기기가 먼저 발권했다면
  /// 실제 번호는 이보다 클 수 있습니다. 에디터 문구를 "이 번호로 발권됩니다"
  /// 에서 **"발권 예정 번호"** 정도로 바꾸는 걸 권합니다.
  String previewSerial(DateTime visitedAt) => ticketSerial(
    year: visitedAt.year,
    seq: (_issued[visitedAt.year] ?? 0) + 1,
  );

  // ── 회원 정보 ───────────────────────────────────

  /// 관람을 시작한 해. 가장 오래된 기록의 연도입니다.
  int get joinedYear {
    if (_tickets.isEmpty) return DateTime.now().year;
    return _tickets.map((t) => t.visitedAt.year).reduce((a, b) => a < b ? a : b);
  }

  /// 회원 번호(`M-2025-0006`).
  ///
  /// ⚠ **로그인 전 폴백입니다.** `joinedYear.hashCode % 9000 + 1` 은 정수
  /// 해시라 **같은 해에 시작한 모든 사용자가 같은 번호**를 받고, 첫 티켓을
  /// 지우면 번호가 바뀝니다. 회원 번호는 바뀌면 안 되는 값입니다.
  /// 로그인 상태에서는 `AuthService.instance.viewer!.memberSerialText`
  /// (= 서버 `profiles.member_no`)를 쓰세요.
  @Deprecated('로그인 상태에서는 AuthService.instance.viewer?.memberSerialText 를 쓰세요')
  String get memberSerialText =>
      memberSerial(since: joinedYear, no: joinedYear.hashCode.abs() % 9000 + 1);

  // ── 레이어 ──────────────────────────────────────

  void addLayer(String ticketId, ScrapLayer layer) {
    byId(ticketId)?.layers.add(layer);
    _changed();
  }

  void removeLayer(String ticketId, String layerId) {
    byId(ticketId)?.layers.removeWhere((l) => l.id == layerId);
    _changed();
  }

  /// 선택한 레이어를 맨 앞으로 올립니다.
  void bringToFront(String ticketId, String layerId) {
    final t = byId(ticketId);
    if (t == null) return;
    final i = t.layers.indexWhere((l) => l.id == layerId);
    if (i < 0 || i == t.layers.length - 1) return;
    final l = t.layers.removeAt(i);
    t.layers.add(l);
    _changed();
  }
}