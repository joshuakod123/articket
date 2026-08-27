import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../models/ticket.dart';
import '../services/auth_service.dart';
import '../services/poster_storage.dart';
import 'local_store.dart';
import 'remote_store.dart';
import 'supabase_env.dart';
import 'ticket_store.dart';

enum SyncState { idle, syncing, offline, error }

/// 동기화 엔진.
///
/// ============================================================================
///  왜 이렇게 만들었는지 — 이 파일에서 가장 중요한 부분
/// ============================================================================
///
/// ## 문제: `Ticket` 은 가변 객체이고, 저장 신호는 `TicketStore.touch()` 하나뿐
///
/// 화면은 `ticket.rating = 4` 처럼 필드를 직접 쓰고 `store.touch()` 를 부릅니다.
/// 시트에 저장 버튼이 없어서 고르는 즉시 반영되는 게 이 앱의 감각이고, 그건
/// 지키고 싶습니다. 그런데 `touch()` 는 **무엇이 바뀌었는지 모릅니다.**
///
/// 흔한 해법 두 가지가 다 별로였습니다.
///
/// 1. **모든 모델에 `updatedAt` 을 달고 호출부를 `touch(ticket)` 으로 바꾸기**
///    — 호출부가 수십 군데입니다. 하나만 빠뜨리면 그 수정은 영원히 서버에
///    안 올라갑니다. 조용히. 사용자가 기기를 바꾸고 나서야 발견됩니다.
/// 2. **`touch()` 마다 전부 올리기** — 스티커를 한 번 끌 때마다 티켓 40장을
///    업로드합니다.
///
/// ## 해법: 내용 해시 그림자(shadow)
///
/// "서버가 갖고 있는 것"의 해시를 id 별로 들고 있습니다. [_rescan] 이 지금
/// 내용의 해시와 비교합니다. 다른 것만 더러운(dirty) 것입니다.
///
/// * 호출부를 **한 줄도** 안 고칩니다. `_changed()` 에 한 줄만 넣습니다.
/// * 되돌리기로 원상복구된 수정은 해시가 같으므로 **안 올라갑니다.**
/// * **삭제도 공짜로 잡힙니다.** 그림자에는 있는데 목록에 없는 id = 지워진 것.
///   `remove()` 를 패치할 필요가 없습니다.
///
/// 비용은 md5 수십 번입니다. 티켓 40장이면 1ms 아래입니다.
///
/// ## 지운 것은 지우지 않습니다 (묘비)
///
/// 서버 행을 진짜로 `delete` 하면, 아직 안 켠 다른 기기는 그 티켓이 지워졌다는
/// 사실을 **영영 모릅니다.** 켜지는 순간 자기가 들고 있던 사본을 다시 올립니다.
/// 지운 티켓이 되살아납니다. 그래서 `deleted_at` 만 찍습니다.
///
/// ## 충돌
///
/// 레코드 단위 last-write-wins 입니다. 티켓 하나는 통째로 한 문서입니다.
/// 필드 단위로 병합하면 "포스터는 폰 것, 별점은 태블릿 것"인 티켓이 나오는데,
/// 사용자는 그걸 자기가 만든 적이 없습니다.
class SyncService extends ChangeNotifier {
  SyncService._();

  static final SyncService instance = SyncService._();

  final _local = LocalStore.instance;
  final _store = TicketStore.instance;

  static const kShadow = 'articket.sync.shadow.v1';
  static const kCursor = 'articket.sync.cursor.v1';
  static const kGrave = 'articket.sync.grave.v1';

  /// 한 번 오갈 때 기다리는 최대 시간.
  static const _budget = Duration(seconds: 45);

  /// id → 서버가 갖고 있는 내용의 해시.
  final Map<String, String> _shadow = {};

  /// id → 이 기기에서 마지막으로 고친 시각. 충돌 판정에 씁니다.
  final Map<String, DateTime> _dirtyAt = {};

  /// id → 지운 시각. 서버에 묘비를 세울 때까지 들고 있습니다.
  final Map<String, DateTime> _grave = {};

  /// 마지막으로 받아온 서버 시각. 다음 pull 은 여기부터.
  String? _cursor;

  SyncState _state = SyncState.idle;
  SyncState get state => _state;

  DateTime? _lastSyncedAt;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  bool _running = false;
  Timer? _debounce;
  bool _attached = false;

  String? get _uid => AuthService.instance.viewer?.id;

  bool get _canSync =>
      SupabaseEnv.isConfigured &&
          AuthService.instance.isSignedIn &&
          (_uid?.isNotEmpty ?? false);

  // ── 붙이기 ──────────────────────────────────────

  /// `AppGate._boot()` 에서 한 번. **[TicketStore.load] 뒤에** 부릅니다.
  Future<void> attach() async {
    if (_attached) return;
    _attached = true;

    final shadow = await _local.readMap(kShadow);
    shadow?.forEach((k, v) => _shadow[k] = '$v');

    final grave = await _local.readMap(kGrave);
    grave?.forEach((k, v) {
      final t = DateTime.tryParse('$v');
      if (t != null) _grave[k] = t;
    });

    _cursor = await _local.readString(kCursor);
  }

  /// **`TicketStore._changed()` 에서 부릅니다. 이 앱에서 이 한 줄이 전부입니다.**
  void noteChange() {
    if (!_attached || !_store.isReady) return;
    _rescan();

    // 스티커를 끄는 동안 매 프레임 올리지 않습니다. 손을 놓고 3초 뒤 한 번.
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () => unawaited(syncNow()));
  }

  /// 지금 내용과 그림자를 비교해 더러운 것 · 지워진 것을 표시합니다.
  void _rescan() {
    if (!_attached || !_store.isReady) return;

    final now = DateTime.now();
    final live = <String>{};

    for (final f in _store.folders) {
      live.add(f.id);
      if (_shadow[f.id] != _hash(f.toJson())) _dirtyAt[f.id] = now;
    }
    for (final t in _store.tickets) {
      live.add(t.id);
      if (_shadow[t.id] != _hash(t.toJson())) _dirtyAt[t.id] = now;
    }

    // 그림자에는 있는데 목록에 없는 것 = 지워진 것. 묘비를 세웁니다.
    for (final id in _shadow.keys) {
      if (!live.contains(id) && !_grave.containsKey(id)) {
        _grave[id] = now;
        _dirtyAt.remove(id);
      }
    }
  }

  // ── 동기화 ──────────────────────────────────────

  /// [full] 이면 커서를 버리고 처음부터 다시 받습니다(기기 교체·계정 전환).
  Future<void> syncNow({bool full = false}) async {
    if (!_canSync || _running || !_store.isReady) return;
    _running = true;
    _set(SyncState.syncing);

    try {
      if (full) _cursor = null;

      // 타임아웃을 개별 쿼리마다 걸지 않고 **한 번에** 겁니다.
      // (postgrest 빌더에 .timeout 을 직접 붙이는 건 버전마다 동작이 달라서
      //  컴파일이 되는데도 엉뚱하게 도는 경우가 있습니다)
      await _roundTrip().timeout(_budget);

      _lastSyncedAt = DateTime.now();
      await _persistMeta();
      _set(SyncState.idle);
    } on TimeoutException {
      _set(SyncState.offline);
    } catch (e) {
      // 동기화 실패로 앱이 멈추면 안 됩니다. 조용히 물러나고 다음에 다시 합니다.
      // _dirtyAt 과 _grave 는 그대로 남으므로 아무것도 잃지 않습니다.
      debugPrint('[sync] $e');
      _set(_looksOffline(e) ? SyncState.offline : SyncState.error);
    } finally {
      _running = false;
    }
  }

  Future<void> _roundTrip() async {
    await _pull();
    await _push();

    // 사진은 마지막입니다. 티켓 행보다 훨씬 무겁습니다.
    final touched = await PosterStorage.instance.syncPhotos(_store.tickets);

    // 업로드가 끝나면 `posterKey` 가 채워집니다. 그 값은 **행에도 들어가야**
    // 다른 기기가 사진을 찾을 수 있습니다. 그래서 한 번 더 밀어 올립니다.
    if (touched) {
      _rescan();
      await _push();
      _store.touch(); // 로컬에도 posterKey/posterPath 를 저장
    }
  }

  /// 나가기 전에 밀어 올리기만. 받아오지 않습니다.
  Future<void> pushPending() async {
    if (!_canSync || !_store.isReady) return;
    try {
      _rescan();
      await _push().timeout(const Duration(seconds: 15));
      await _persistMeta();
    } catch (_) {}
  }

  // ── 받아오기 ────────────────────────────────────

  Future<void> _pull() async {
    final uid = _uid!;
    var cursor = _cursor ?? '1970-01-01T00:00:00Z';

    for (var page = 0; page < 40; page++) {
      final folders = await sb
          .from('folders')
          .select()
          .eq('user_id', uid)
          .gt('updated_at', cursor)
          .order('updated_at')
          .limit(200);

      final tickets = await sb
          .from('tickets')
          .select()
          .eq('user_id', uid)
          .gt('updated_at', cursor)
          .order('updated_at')
          .limit(200);

      if (folders.isEmpty && tickets.isEmpty) break;

      // 서류철을 **먼저** 반영합니다. 티켓이 먼저 들어오면 잠깐이지만
      // 없는 서류철을 가리키는 티켓이 생깁니다.
      for (final r in folders) {
        _applyFolder(Map<String, dynamic>.from(r));
      }
      for (final r in tickets) {
        _applyTicket(Map<String, dynamic>.from(r));
      }

      final next = _latest([...folders, ...tickets]);
      if (next == null || next == cursor) break; // 같은 시각이 200개 넘는 경우
      cursor = next;
      _cursor = cursor;

      if (folders.length < 200 && tickets.length < 200) break;
    }

    _store.touch(); // 화면 갱신 + 로컬 저장
  }

  void _applyFolder(Map<String, dynamic> r) {
    final id = r['id'] as String;
    final remoteAt = DateTime.tryParse('${r['updated_at']}');

    if (r['deleted_at'] != null) {
      if (_shouldYield(id, remoteAt)) {
        _store.removeFolderQuiet(id);
        _shadow.remove(id);
        _dirtyAt.remove(id);
        _grave.remove(id);
      }
      return;
    }
    if (!_shouldYield(id, remoteAt)) return;

    final incoming = RemoteStore.folderFromRow(r);
    _store.upsertFolderQuiet(incoming);
    _shadow[id] = _hash(incoming.toJson());
    _dirtyAt.remove(id);
  }

  void _applyTicket(Map<String, dynamic> r) {
    final id = r['id'] as String;
    final remoteAt = DateTime.tryParse('${r['updated_at']}');

    if (r['deleted_at'] != null) {
      if (_shouldYield(id, remoteAt)) {
        _store.removeQuiet(id);
        _shadow.remove(id);
        _dirtyAt.remove(id);
        _grave.remove(id);
      }
      return;
    }
    if (!_shouldYield(id, remoteAt)) return;

    final incoming = RemoteStore.ticketFromRow(r);

    // 이 기기에 이미 사진이 내려와 있으면 경로를 물려줍니다.
    // 서버 행에는 로컬 경로가 없으므로, 안 물려주면 사진이 사라져 보입니다.
    // **해시를 뜨기 전에** 넣어야 합니다. 안 그러면 방금 받은 티켓이 곧바로
    // 더러운 것으로 잡혀 서버로 되올라갑니다.
    incoming.posterPath = _store.byId(id)?.posterPath;

    _store.upsertQuiet(incoming);
    _shadow[id] = _hash(incoming.toJson());
    _dirtyAt.remove(id);
  }

  /// 원격 것을 받아들일지. 로컬이 더 최근이면 물러납니다(다음 push 가 올립니다).
  bool _shouldYield(String id, DateTime? remoteAt) {
    final localAt = _dirtyAt[id] ?? _grave[id];
    if (localAt == null) return true; // 로컬은 안 건드림 → 원격 채택
    if (remoteAt == null) return false;
    return remoteAt.isAfter(localAt);
  }

  // ── 밀어 올리기 ──────────────────────────────────

  Future<void> _push() async {
    final uid = _uid!;

    // 0. 첫 동기화라면, 이미 기기에서 찍혀 있던 번호만큼 서버 카운터를 올립니다.
    //    안 하면 서버가 1번부터 발급해서 유니크 제약에 걸립니다.
    if (_cursor == null) {
      final top = <int, int>{};
      for (final t in _store.tickets) {
        if (!t.isIssued) continue;
        if (t.issuedSeq > (top[t.issuedYear] ?? 0)) {
          top[t.issuedYear] = t.issuedSeq;
        }
      }
      for (final e in top.entries) {
        await RemoteStore.raiseCounter(e.key, e.value);
      }
    }

    // 1. 미발권 티켓에 번호를 받아 찍습니다(오프라인에서 만든 것들).
    for (final t in _store.tickets) {
      if (t.isIssued) continue;
      final seq = await RemoteStore.issueSerial(t.visitedAt.year);
      if (seq == null) break; // 네트워크가 나갔으면 다음 기회에
      t.issuedYear = t.visitedAt.year;
      t.issuedSeq = seq;
      _dirtyAt[t.id] = DateTime.now();
    }

    // 2. 서류철 먼저 (티켓이 가리키므로)
    final folders = _store.folders;
    final dirtyFolders = <Map<String, dynamic>>[];
    for (var i = 0; i < folders.length; i++) {
      final f = folders[i];
      if (!_dirtyAt.containsKey(f.id)) continue;
      dirtyFolders.add(RemoteStore.folderRow(f, uid, i));
    }
    if (dirtyFolders.isNotEmpty) {
      await sb.from('folders').upsert(dirtyFolders);
      for (final f in folders) {
        if (!_dirtyAt.containsKey(f.id)) continue;
        _shadow[f.id] = _hash(f.toJson());
        _dirtyAt.remove(f.id);
      }
    }

    // 3. 티켓. 한 번에 다 올리면 요청이 커집니다(레이어 많은 티켓은 수십 KB).
    final dirtyTickets = <Ticket>[
      for (final t in _store.tickets)
        if (_dirtyAt.containsKey(t.id)) t
    ];
    for (var i = 0; i < dirtyTickets.length; i += 50) {
      final end = (i + 50) < dirtyTickets.length ? i + 50 : dirtyTickets.length;
      final chunk = dirtyTickets.sublist(i, end);
      await sb
          .from('tickets')
          .upsert([for (final t in chunk) RemoteStore.ticketRow(t, uid)]);
      for (final t in chunk) {
        _shadow[t.id] = _hash(t.toJson());
        _dirtyAt.remove(t.id);
      }
    }

    // 4. 묘비. 행을 진짜로 지우지 않는 이유는 클래스 문서에 적어두었습니다.
    if (_grave.isNotEmpty) {
      final ids = _grave.keys.toList();
      final stamp = DateTime.now().toUtc().toIso8601String();
      for (final table in ['tickets', 'folders']) {
        await sb
            .from(table)
            .update({'deleted_at': stamp})
            .inFilter('id', ids)
            .eq('user_id', uid);
      }
      await PosterStorage.instance.removeRemote(ids);
      for (final id in ids) {
        _grave.remove(id);
        _shadow.remove(id);
      }
    }
  }

  // ── 계정 전환 · 입양 · 초기화 ─────────────────────

  /// 이 기기의 로컬 기록을 **지금 로그인한 계정 것으로** 올립니다.
  /// 그림자를 비우면 전부 더러운 것으로 잡히고, 그대로 올라갑니다.
  ///
  /// ⚠ **가입 직후에는 더 이상 부르지 않습니다.**
  ///
  /// 이 앱은 로그인해야 들어올 수 있습니다(`AppGate`). 그래서 가입 시점에
  /// 기기에 남아 있는 기록은 "로그인 전에 내가 만든 것"이 아니라 **앞서
  /// 로그아웃한 다른 사람의 것**이거나 구버전 예시입니다. 그걸 입양하면 남의
  /// 관람 기록이 새 계정의 서버로 올라갑니다.
  ///
  /// 로그인 없이 쓰는 모드(게스트)를 나중에 열면 그때 다시 쓰세요.
  /// 그 전까지는 호출부가 없는 것이 맞습니다.
  Future<void> adoptLocalDataThenSync() async {
    _shadow.clear();
    _grave.clear();
    _cursor = null;
    final now = DateTime.now();
    for (final f in _store.folders) {
      _dirtyAt[f.id] = now;
    }
    for (final t in _store.tickets) {
      _dirtyAt[t.id] = now;
    }
    await syncNow(full: true);
  }

  /// 탈퇴·계정 전환에서. 동기화 상태를 통째로 버립니다.
  ///
  /// **[TicketStore.wipe] 가 리스트를 비우기 전에 이걸 먼저 부릅니다.**
  /// 순서가 반대면 [noteChange] 가 "티켓이 전부 사라졌다"고 판단해 서버
  /// 데이터에 묘비를 세웁니다. 로그아웃하려던 사용자의 기록이 서버에서도
  /// 지워집니다.
  Future<void> reset() async {
    _debounce?.cancel();
    _shadow.clear();
    _dirtyAt.clear();
    _grave.clear();
    _cursor = null;
    _lastSyncedAt = null;
    await _local.delete(kShadow);
    await _local.delete(kCursor);
    await _local.delete(kGrave);
    _set(SyncState.idle);
  }

  // ── 잡일 ────────────────────────────────────────

  Future<void> _persistMeta() async {
    await _local.write(kShadow, _shadow);
    await _local.write(
        kGrave, _grave.map((k, v) => MapEntry(k, v.toIso8601String())));
    if (_cursor != null) await _local.writeString(kCursor, _cursor!);
  }

  static String _hash(Map<String, dynamic> j) {
    // jsonEncode 는 Map 의 삽입 순서를 지킵니다. toJson() 이 리터럴이라 순서가
    // 항상 같습니다. 모델을 고칠 때 키 순서를 바꾸면 전 레코드가 한 번 더
    // 올라갑니다 — 틀린 결과는 아니고 트래픽만 한 번 더 씁니다.
    return md5.convert(utf8.encode(jsonEncode(j))).toString();
  }

  static String? _latest(List<dynamic> rows) {
    String? top;
    for (final r in rows) {
      final v = (r as Map)['updated_at']?.toString();
      if (v == null) continue;
      if (top == null || v.compareTo(top) > 0) top = v;
    }
    return top;
  }

  static bool _looksOffline(Object e) {
    final s = e.toString();
    return s.contains('SocketException') ||
        s.contains('Failed host lookup') ||
        s.contains('ClientException');
  }

  void _set(SyncState s) {
    if (_state == s) return;
    _state = s;
    notifyListeners();
  }
}