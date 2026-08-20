import 'package:flutter/foundation.dart';

import '../models/ticket.dart';
import '../models/layer.dart';
import 'mock_data.dart';
import 'serial.dart';

/// 인메모리 저장소.
///
/// Phase 1에서는 이 클래스의 메서드 본문만 Hive/Isar 호출로 바꾸면 됩니다.
/// UI는 [ListenableBuilder]로 이 객체만 구독하므로 화면 코드는 손댈 필요가 없습니다.
class TicketStore extends ChangeNotifier {
  TicketStore._() {
    _folders.addAll(mockFolders);
    _tickets.addAll(mockTickets);
    _renumber();
  }

  static final TicketStore instance = TicketStore._();

  final List<ArchiveFolder> _folders = [];
  final List<Ticket> _tickets = [];

  List<ArchiveFolder> get folders => List.unmodifiable(_folders);
  List<Ticket> get tickets => List.unmodifiable(_tickets);

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

  // ── 서류철 관리 ─────────────────────────────────

  void addFolder(ArchiveFolder folder) {
    _folders.add(folder);
    notifyListeners();
  }

  /// 서류철을 버립니다. 안에 철해둔 티켓도 함께 사라집니다.
  void removeFolder(String id) {
    _folders.removeWhere((f) => f.id == id);
    _tickets.removeWhere((t) => t.folderId == id);
    notifyListeners();
  }

  ArchiveFolder? folderById(String id) {
    for (final f in _folders) {
      if (f.id == id) return f;
    }
    return null;
  }

  void add(Ticket ticket) {
    _tickets.add(ticket);
    _renumber();
    notifyListeners();
  }

  void remove(String id) {
    _tickets.removeWhere((t) => t.id == id);
    _renumber();
    notifyListeners();
  }

  /// 티켓 내용을 바꾼 뒤 호출합니다. (Ticket 필드가 가변이라 갱신만 알립니다)
  ///
  /// 관람일이 바뀌었을 수 있으므로 번호도 같이 다시 매깁니다.
  /// 40장 남짓을 정렬하는 정도라 매 편집마다 돌려도 부담이 없습니다.
  void touch() {
    _renumber();
    notifyListeners();
  }

  // ── 발권 번호 ───────────────────────────────────

  /// 티켓 전체의 [Ticket.serial]을 관람일 기준으로 다시 매깁니다.
  ///
  /// **연도별로 1번부터.** 그래서 `AK-2026-003`은 언제 봐도
  /// "2026년에 본 것 중 세 번째"입니다. 중간 티켓을 지우면 뒤 번호가
  /// 한 칸씩 당겨지는데, 실물 티켓북을 다시 철하는 것과 같아서
  /// 빈 번호가 남는 것보다 이쪽이 덜 어색합니다.
  ///
  /// 같은 날 본 것끼리는 [Ticket.id]로 순서를 고정합니다. 이게 없으면
  /// 목록 순서가 흔들릴 때마다 번호가 서로 바뀝니다.
  void _renumber() {
    final byYear = <int, List<Ticket>>{};
    for (final t in _tickets) {
      byYear.putIfAbsent(t.visitedAt.year, () => []).add(t);
    }
    for (final entry in byYear.entries) {
      final list = entry.value
        ..sort((a, b) {
          final d = a.visitedAt.compareTo(b.visitedAt);
          return d != 0 ? d : a.id.compareTo(b.id);
        });
      for (var i = 0; i < list.length; i++) {
        list[i].serial = ticketSerial(year: entry.key, seq: i + 1);
      }
    }
  }

  // ── 회원 정보 ───────────────────────────────────

  /// 관람을 시작한 해. 가장 오래된 기록의 연도입니다.
  ///
  /// 회원증의 커다란 세로 숫자, "○○년부터 △장", 회원 번호가 **모두 이 값**을
  /// 씁니다. 예전에는 큰 숫자만 이 값이고 번호는 `DateTime.now().year`라서
  /// 한 카드 안에서 2025와 2026이 동시에 보였습니다.
  int get joinedYear {
    if (_tickets.isEmpty) return DateTime.now().year;
    return _tickets
        .map((t) => t.visitedAt.year)
        .reduce((a, b) => a < b ? a : b);
  }

  /// 회원 번호(`M-2025-0006`).
  ///
  /// 시작 연도만 가지고 만듭니다. **티켓 수가 아닙니다.** 티켓을 한 장
  /// 추가할 때마다 회원 번호가 바뀌던 게 이 화면의 가장 큰 거짓말이었습니다.
  /// 뒷자리는 시작 연도에서 뽑은 고정 값이라, 기기가 같으면 늘 같습니다.
  String get memberSerialText =>
      memberSerial(since: joinedYear, no: joinedYear.hashCode.abs() % 9000 + 1);

  void addLayer(String ticketId, ScrapLayer layer) {
    byId(ticketId)?.layers.add(layer);
    notifyListeners();
  }

  void removeLayer(String ticketId, String layerId) {
    byId(ticketId)?.layers.removeWhere((l) => l.id == layerId);
    notifyListeners();
  }

  /// 선택한 레이어를 맨 앞으로 올립니다.
  void bringToFront(String ticketId, String layerId) {
    final t = byId(ticketId);
    if (t == null) return;
    final i = t.layers.indexWhere((l) => l.id == layerId);
    if (i < 0 || i == t.layers.length - 1) return;
    final l = t.layers.removeAt(i);
    t.layers.add(l);
    notifyListeners();
  }
}