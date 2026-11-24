import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/supabase_env.dart';
import '../models/ticket.dart';
import '../models/layer.dart';
import 'auth_service.dart';

/// Durable original files, private upload keys and per-device offline caches.
class PosterStorage {
  PosterStorage._();
  static final instance = PosterStorage._();
  static const _bucket = 'posters';
  Directory? _dir;
  bool lastSyncHadErrors = false;
  Future<Directory> get _posterDir async {
    if (_dir != null) return _dir!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/posters');
    await dir.create(recursive: true);
    return _dir = dir;
  }

  Future<String> adopt(String path, String id) async {
    final source = File(path);
    if (!await source.exists()) {
      throw FileSystemException('사진 원본을 찾지 못했어요', path);
    }
    final destination = File(
      '${(await _posterDir).path}/$id-${DateTime.now().microsecondsSinceEpoch}${_ext(path)}',
    );
    await source.copy(destination.path);
    return destination.path;
  }

  Future<bool> syncPhotos(
    List<Ticket> tickets, {
    List<ArchiveFolder> folders = const [],
    bool Function()? isCurrent,
  }) async {
    lastSyncHadErrors = false;
    if (!SupabaseEnv.isConfigured) return false;
    final uid = AuthService.instance.viewer?.id;
    if (uid == null) return false;
    bool valid() =>
        AuthService.instance.viewer?.id == uid && (isCurrent?.call() ?? true);
    var changed = false;
    Future<void> asset(
      String parent,
      String id,
      String? path,
      String? key,
      String? Function() currentPath,
      String? Function() currentKey,
      void Function(String) onPath,
      void Function(String) onKey,
    ) async {
      if (!valid()) return;
      try {
        final exists =
            path != null && path.isNotEmpty && await File(path).exists();
        if (exists && (key == null || key.isEmpty)) {
          final uploaded =
              '$uid/$parent-$id-${DateTime.now().microsecondsSinceEpoch}${_ext(path)}';
          await sb.storage
              .from(_bucket)
              .upload(
                uploaded,
                File(path),
                fileOptions: const FileOptions(upsert: false),
              );
          if (!valid()) return;
          if (currentPath() == path && currentKey() == key) {
            onKey(uploaded);
            changed = true;
          } else {
            await sb.storage.from(_bucket).remove([uploaded]);
          }
        } else if (!exists && key != null && key.isNotEmpty) {
          final bytes = await sb.storage.from(_bucket).download(key);
          if (!valid() || currentKey() != key) return;
          final local = File(
            '${(await _posterDir).path}/${key.split('/').last}',
          );
          await local.writeAsBytes(bytes, flush: true);
          if (!valid() || currentKey() != key) return;
          onPath(local.path);
          changed = true;
        } else if (path != null && path.isNotEmpty && !exists) {
          lastSyncHadErrors = true;
        }
      } catch (e) {
        lastSyncHadErrors = true;
        debugPrint('[photo] $e');
      }
    }

    Future<void> layers(String parent, List<ScrapLayer> items) async {
      for (final l in items.where((l) => l.kind == LayerKind.photo)) {
        await asset(
          parent,
          l.id,
          l.content,
          l.photoKey,
          () => l.content,
          () => l.photoKey,
          (v) => l.content = v,
          (v) => l.photoKey = v,
        );
      }
    }

    for (final t in tickets) {
      await asset(
        t.id,
        'poster',
        t.posterPath,
        t.posterKey,
        () => t.posterPath,
        () => t.posterKey,
        (v) => t.posterPath = v,
        (v) => t.posterKey = v,
      );
      await layers(t.id, t.layers);
    }
    for (final f in folders) {
      await layers(f.id, f.pageLayers);
    }
    return changed;
  }

  Future<void> removeRemote(List<String> ids) async {
    if (!SupabaseEnv.isConfigured || ids.isEmpty) return;
    final uid = AuthService.instance.viewer?.id;
    if (uid == null) return;
    var offset = 0;
    final keys = <String>[];
    while (true) {
      final files = await sb.storage
          .from(_bucket)
          .list(
            path: uid,
            searchOptions: SearchOptions(limit: 100, offset: offset),
          );
      keys.addAll(
        files
            .where((f) => ids.any((id) => f.name.startsWith(id)))
            .map((f) => '$uid/${f.name}'),
      );
      if (files.length < 100) break;
      offset += 100;
    }
    for (var i = 0; i < keys.length; i += 100) {
      await sb.storage.from(_bucket).remove(keys.skip(i).take(100).toList());
    }
  }

  Future<void> wipeLocal() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/posters');
      if (await dir.exists()) await dir.delete(recursive: true);
      _dir = null;
    } catch (_) {}
  }

  static String _ext(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(ext)
        ? '.$ext'
        : '.jpg';
  }
}
