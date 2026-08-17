import 'package:flutter/foundation.dart';

import '../models/ticket.dart';
import '../models/layer.dart';
import 'mock_data.dart';

/// 인메모리 저장소.
///
/// Phase 1에서는 이 클래스의 메서드 본문만 Hive/Isar 호출로 바꾸면 됩니다.
/// UI는 [ListenableBuilder]로 이 객체만 구독하므로 화면 코드는 손댈 필요가 없습니다.
class TicketStore extends ChangeNotifier {
  TicketStore._() {
    _folders.addAll(mockFolders);
    _tickets.addAll(mockTickets);
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
    notifyListeners();
  }

  void remove(String id) {
    _tickets.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  /// 티켓 내용을 바꾼 뒤 호출합니다. (Ticket 필드가 가변이라 갱신만 알립니다)
  void touch() => notifyListeners();

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