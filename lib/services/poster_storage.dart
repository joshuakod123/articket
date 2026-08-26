import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_env.dart';
import '../models/ticket.dart';
import 'auth_service.dart';

/// 티켓 포스터 사진.
///
/// ## 먼저 고치는 것 — 로컬 경로가 사라지는 문제
///
/// 로드맵에 "사진 영구 보관 — `posterPath` 를 `getApplicationDocumentsDirectory()`
/// 로 복사"가 열린 항목으로 남아 있습니다. **서버보다 이게 먼저입니다.**
///
/// `image_picker` 가 돌려주는 경로는 **캐시 디렉터리**입니다. iOS 는 저장공간이
/// 부족하면 예고 없이 비우고, 안드로이드도 마찬가지입니다. 앱을 업데이트해도
/// 날아갑니다. 즉 지금 상태로 서버에 올리면, 사용자가 사진을 고른 그 세션에
/// 동기화가 안 돌면 그 사진은 **원본이 이미 없습니다.** 올릴 것도 없습니다.
///
/// ```
///   image_picker  →  adopt()  →  문서 디렉터리(영구)  →  syncPhotos()  →  Storage
/// ```
///
/// ## 왜 서명 URL 로 바로 안 그리고 파일로 내려받나
///
/// 이 앱은 서랍을 여는 데 네트워크가 필요하면 안 됩니다. `Image.network` 로
/// 그리면 비행기 안에서 스크랩북이 회색 사각형이 됩니다. 그래서 파일로
/// 내려받아 문서 디렉터리에 두고, 화면은 예전처럼 로컬 파일만 봅니다.
/// 화면 코드가 한 줄도 안 바뀌는 것도 덤입니다.
class PosterStorage {
  PosterStorage._();

  static final PosterStorage instance = PosterStorage._();

  static const _bucket = 'posters';

  Directory? _dir;

  Future<Directory> get _posterDir async {
    if (_dir != null) return _dir!;
    final docs = await getApplicationDocumentsDirectory();
    final d = Directory('${docs.path}/posters');
    if (!await d.exists()) await d.create(recursive: true);
    return _dir = d;
  }

  // ── 1. 고른 사진을 영구 보관 ─────────────────────

  /// `image_picker` 가 준 임시 파일을 문서 디렉터리로 복사하고 새 경로를 줍니다.
  /// 사진을 고른 **직후** 부르세요. 실패하면 원본 경로를 그대로 돌려줍니다
  /// (복사에 실패했다고 사진 선택 자체를 취소시키는 건 과합니다).
  Future<String> adopt(String tempPath, String ticketId) async {
    try {
      final src = File(tempPath);
      if (!await src.exists()) return tempPath;

      final dst = File('${(await _posterDir).path}/$ticketId${_ext(tempPath)}');
      await src.copy(dst.path);
      return dst.path;
    } catch (e) {
      debugPrint('[poster] adopt failed: $e');
      return tempPath;
    }
  }

  // ── 2. 서버와 맞추기 ─────────────────────────────

  /// 올릴 것은 올리고, 내려받을 것은 내려받습니다. [SyncService] 가 부릅니다.
  ///
  /// 사진은 티켓 행보다 훨씬 무겁습니다. 실패해도 **던지지 않습니다** —
  /// 사진 하나가 안 올라갔다고 티켓 40장의 동기화를 되돌릴 이유가 없습니다.
  Future<void> syncPhotos(List<Ticket> tickets) async {
    if (!SupabaseEnv.isConfigured) return;
    final uid = AuthService.instance.viewer?.id;
    if (uid == null || uid.isEmpty) return;

    for (final t in tickets) {
      try {
        final hasLocal = t.posterPath != null &&
            t.posterPath!.isNotEmpty &&
            await File(t.posterPath!).exists();

        // (a) 이 기기에 원본이 있고 서버엔 없음 → 올림
        if (hasLocal && (t.posterKey == null || t.posterKey!.isEmpty)) {
          final key = '$uid/${t.id}${_ext(t.posterPath!)}';
          await sb.storage.from(_bucket).upload(
            key,
            File(t.posterPath!),
            fileOptions: const FileOptions(upsert: true),
          );
          t.posterKey = key;
          continue;
        }

        // (b) 서버엔 있는데 이 기기엔 없음 → 내려받음 (기기 교체·재설치)
        if (!hasLocal && t.posterKey != null && t.posterKey!.isNotEmpty) {
          final bytes = await sb.storage.from(_bucket).download(t.posterKey!);
          final dst =
          File('${(await _posterDir).path}/${t.id}${_ext(t.posterKey!)}');
          await dst.writeAsBytes(bytes, flush: true);
          t.posterPath = dst.path;
        }
      } catch (e) {
        debugPrint('[poster] ${t.id}: $e');
      }
    }
  }

  /// 티켓이 지워질 때 서버 사진도 같이. 묘비만 세우면 파일은 계속 요금을 씁니다.
  Future<void> removeRemote(List<String> ticketIds) async {
    if (!SupabaseEnv.isConfigured || ticketIds.isEmpty) return;
    final uid = AuthService.instance.viewer?.id;
    if (uid == null || uid.isEmpty) return;

    try {
      // 확장자를 모르므로 폴더를 훑어 이름으로 맞춥니다.
      final files = await sb.storage.from(_bucket).list(path: uid);
      final targets = <String>[
        for (final f in files)
          if (ticketIds.any((id) => f.name.startsWith(id))) '$uid/${f.name}'
      ];
      if (targets.isNotEmpty) {
        await sb.storage.from(_bucket).remove(targets);
      }
    } catch (e) {
      debugPrint('[poster] remote cleanup: $e');
    }
  }

  /// 탈퇴 뒤 기기에 남은 사진 정리. `LocalStore.wipe()` 는 이걸 모릅니다.
  Future<void> wipeLocal() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final d = Directory('${docs.path}/posters');
      if (await d.exists()) await d.delete(recursive: true);
      _dir = null;
    } catch (_) {}
  }

  static String _ext(String path) {
    final i = path.lastIndexOf('.');
    if (i < 0 || path.length - i > 6) return '.jpg';
    return path.substring(i).toLowerCase();
  }
}