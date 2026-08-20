import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/layer.dart';
import '../models/ticket.dart';
import 'local_store.dart';
import 'mock_data.dart';
import 'serial.dart';

/// 티켓·서류철 저장소.
///
/// ## 바뀐 점 두 가지
///
/// **1. 진짜로 저장합니다.** 예전에는 생성자에서 `mockTickets`를 부어 넣는
/// 인메모리였습니다. 사용자가 만든 티켓은 앱을 끄면 사라졌고, 그래서 발권
/// 번호도 매번 처음부터 다시 매겨졌습니다. 이제 [load]가 기기에서 읽고,
/// 바뀔 때마다 [_persist]가 씁니다.
///
/// **2. 발권 번호를 다시 매기지 않습니다.** `_renumber()`를 걷어냈습니다.
/// 자세한 이유는 `lib/data/serial.dart` 문서에 적어 두었습니다. 요약하면,
/// 번호는 티켓을 만드는 순간 한 번 찍히고 그 뒤로 바뀌지 않습니다.
/// 지운 번호는 다시 쓰지 않으므로 [_issued]에 연도별 최고값을 들고 있습니다.
class TicketStore extends ChangeNotifier {
  TicketStore._();

  static final TicketStore instance = TicketStore._();

  final _local = LocalStore.instance;

  final List<ArchiveFolder> _folders = [];
  final List<Ticket> _tickets = [];

  /// 연도별로 **지금까지 찍은 가장 큰 번호**. 다음 번호는 여기에 +1 입니다.
  ///
  /// 티켓 목록에서 계산하지 않고 따로 들고 있는 게 핵심입니다.
  /// 목록에서 세면 티켓을 지웠을 때 번호가 되쓰여서, 서로 다른 두 티켓이
  /// 같은 번호를 갖게 됩니다.
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

    // 처음 켠 기기에만 예시를 깔아 둡니다.
    // `seeded` 플래그를 따로 두는 이유: 사용자가 예시를 전부 지운 뒤 앱을
    // 다시 켰을 때 예시가 되살아나면 안 되기 때문입니다.
    if (!seeded && _folders.isEmpty && _tickets.isEmpty) {
      _seed();
      await _local.writeFlag(LocalStore.kSeeded, true);
    }

    // 구버전에서 올라온, 아직 번호가 없는 티켓에 지금 도장을 찍습니다.
    _issueMissing();
    _syncIssuedFloor();

    _ready = true;
    await _persist();
    notifyListeners();
  }

  void _seed() {
    _folders.addAll(mockFolders);
    _tickets.addAll(mockTickets);
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
  }

  /// 탈퇴에서 씁니다. 메모리와 기기 양쪽을 비웁니다.
  Future<void> wipe() async {
    _tickets.clear();
    _folders.clear();
    _issued.clear();
    _ready = false;
    await _local.wipe();
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

  /// 티켓을 철합니다. **이 자리에서 번호가 딱 한 번 찍힙니다.**
  void add(Ticket ticket) {
    if (!ticket.isIssued) _stamp(ticket);
    _tickets.add(ticket);
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

  // ── 발권 ────────────────────────────────────────

  /// 다음 번호를 뽑아 티켓에 찍습니다.
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

  /// 다음에 찍힐 번호 미리보기. 에디터에서 "이 번호로 발권됩니다" 표시용.
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

  /// 회원 번호(`M-2025-0006`). 티켓 수가 아니라 시작 연도만 씁니다.
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