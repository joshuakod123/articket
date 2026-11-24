import 'dart:convert';
import '../models/ticket.dart';
import 'supabase_env.dart';

/// 로컬 모델 ↔ Postgres 행 사이의 번역기.
///
/// **여기 말고 다른 데서 컬럼 이름을 쓰지 마세요.** 스키마가 바뀌면 고칠 자리가
/// 이 파일 하나여야 합니다.
///
/// ## 왜 payload jsonb 를 섞어 쓰나
///
/// 전부 컬럼으로 펴면 스티커 속성 하나 늘 때마다 마이그레이션을 씁니다.
/// 전부 jsonb 로 뭉치면 "이 전시를 본 사람들"을 못 셉니다.
/// 그래서 **서버가 물어봐야 하는 것만** 컬럼으로 올립니다.
///
/// | 컬럼으로 | 왜 |
/// |---|---|
/// | title · venue · visited_at | 전시 마스터 매칭 |
/// | issued_year · issued_seq | 유니크 제약이 걸림 |
/// | rating · one_liner | 전시 페이지에 노출 |
/// | is_public | 정책이 읽음 |
/// | poster_key | 스토리지 정리 |
///
/// 나머지(레이어·틴트·프레임·배치·감상문)는 payload 입니다.
///
/// ## note 를 컬럼으로 올리지 않은 것은 실수가 아닙니다
///
/// 감상문은 이 앱에서 가장 사적인 값입니다. 컬럼에 있으면 언젠가 누군가
/// `select t.*` 로 공개 뷰를 짭니다. payload 안에 있으면 그 사고가 안 납니다.
class RemoteStore {
  const RemoteStore._();

  /// 컬럼으로 승격된 키. payload 를 만들 때 여기 있는 것들을 뺍니다.
  static const _promoted = {
    'id', 'folderId', 'title', 'venue', 'visitedAt',
    'issuedYear', 'issuedSeq', 'genre', 'rating', 'oneLiner',
    'isPublic', 'posterKey',
    'serial', // 사람이 읽으라고 넣던 파생값. 서버에 두면 두 벌이 됩니다
    'posterPath', // ⚠ 기기 안의 경로. 다른 기기에서는 아무 의미가 없습니다
  };

  // ── 티켓 ────────────────────────────────────────

  static Map<String, dynamic> ticketRow(Ticket t, String uid) {
    final j = t.toJson();
    return {
      'id': t.id,
      'user_id': uid,
      'folder_id': t.folderId,
      'title': t.title,
      'venue': t.venue,
      'visited_at': _date(t.visitedAt),
      'issued_year': t.issuedYear,
      'issued_seq': t.issuedSeq,
      'genre': t.genre,
      'rating': t.rating,
      'one_liner': t.oneLiner,
      'is_public': t.isPublic,
      'poster_key': t.posterKey,
      'deleted_at': null, // 되살아난 경우(묘비 뒤 재생성)를 위해 명시적으로 비웁니다
      'payload': {
        for (final e in j.entries)
          if (!_promoted.contains(e.key))
            e.key: e.key == 'layers' ? cloudLayers(e.value) : e.value,
      },
    };
  }

  static Ticket ticketFromRow(Map<String, dynamic> r) {
    final payload = Map<String, dynamic>.from(
      (r['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    return Ticket.fromJson({
      ...payload,
      'id': r['id'],
      'folderId': r['folder_id'] ?? '',
      'title': r['title'] ?? '',
      'venue': r['venue'] ?? '',
      'visitedAt': _iso(r['visited_at']),
      'issuedYear': r['issued_year'] ?? 0,
      'issuedSeq': r['issued_seq'] ?? 0,
      'genre': r['genre'] ?? '미술',
      'rating': r['rating'] ?? 0,
      'oneLiner': r['one_liner'] ?? '',
      'isPublic': r['is_public'] ?? false,
      'posterKey': r['poster_key'],
      // posterPath 는 **넣지 않습니다.** 이 기기에 사진이 내려와 있으면
      // SyncService 가 기존 값을 물려주고, 없으면 PosterStorage 가 받아옵니다.
      // 남의 기기 경로를 물려받으면 그 자리에 영원히 깨진 이미지가 뜹니다.
    });
  }

  // ── 서류철 ──────────────────────────────────────

  static Map<String, dynamic> folderRow(
    ArchiveFolder f,
    String uid,
    int index,
  ) {
    final j = f.toJson();
    return {
      'id': f.id,
      'user_id': uid,
      'label': f.label,
      'subtitle': f.subtitle,
      'sort_index': index,
      'deleted_at': null,
      'payload': {
        for (final e in j.entries)
          if (!{'id', 'label', 'subtitle'}.contains(e.key))
            e.key: e.key == 'pageLayers' ? cloudLayers(e.value) : e.value,
      },
    };
  }

  static ArchiveFolder folderFromRow(Map<String, dynamic> r) {
    final payload = Map<String, dynamic>.from(
      (r['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    return ArchiveFolder.fromJson({
      ...payload,
      'id': r['id'],
      'label': r['label'] ?? '',
      'subtitle': r['subtitle'] ?? '',
    });
  }

  // ── 발권 ────────────────────────────────────────

  /// 서버에서 번호를 받습니다. 실패하면 null — 티켓은 미발권으로 남습니다.
  static Future<int?> issueSerial(int year) async {
    try {
      final n = await sb.rpc('issue_ticket_serial', params: {'p_year': year});
      return n is int ? n : int.tryParse('$n');
    } catch (_) {
      return null;
    }
  }

  /// 기기에서 이미 찍혀 올라온 번호가 서버 카운터보다 높을 때 끌어올립니다.
  /// 첫 동기화에서 한 번만 부르면 됩니다.
  static Future<void> raiseCounter(int year, int seq) async {
    try {
      await sb.rpc(
        'raise_ticket_counter',
        params: {'p_year': year, 'p_seq': seq},
      );
    } catch (_) {}
  }

  /// Local paths must never be sent to another device as if they were assets.
  static String cloudLayers(Object? raw) {
    final layers = jsonDecode(raw as String? ?? '[]') as List;
    return jsonEncode(
      layers.map((v) {
        final m = Map<String, dynamic>.from(v as Map);
        if (m['kind'] == 'photo') m['content'] = '';
        return m;
      }).toList(),
    );
  }

  // ── 날짜 ────────────────────────────────────────
  //
  // 컬럼이 `date` 입니다. ISO 문자열을 그대로 넣으면 시간대 때문에 하루가
  // 밀립니다 — 한국 시간 자정 직후에 기록한 전시가 서버에서 전날이 됩니다.
  // 관람일은 시각이 아니라 **날짜**이므로 로컬 달력 기준으로 자릅니다.

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _iso(Object? raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '');
    if (d == null) return DateTime.now().toIso8601String();
    // date 컬럼은 UTC 자정으로 옵니다. 로컬 자정으로 옮겨 담습니다.
    return DateTime(d.year, d.month, d.day).toIso8601String();
  }
}
