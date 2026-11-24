import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../models/layer.dart';
import '../services/auth_service.dart';
import '../services/poster_storage.dart';
import 'local_store.dart';
import 'remote_store.dart';
import 'supabase_env.dart';
import 'ticket_store.dart';

enum SyncState { idle, syncing, offline, error }

/// A durable content-hash outbox. Unacknowledged edits survive restarts and
/// take precedence over pulled rows. Acknowledgements describe the sent
/// snapshot, never a mutable object that may have changed during an upload.
class SyncService extends ChangeNotifier {
  SyncService._();
  static final instance = SyncService._();
  final _local = LocalStore.instance;
  final _store = TicketStore.instance;
  static const kShadow = 'articket.sync.shadow.v1';
  static const kGrave = 'articket.sync.grave.v1';
  static const kCursor = 'articket.sync.cursors.v2';
  static const kDirty = 'articket.sync.dirty.v2';
  final _shadow = <String, String>{};
  final _dirty = <String, String>{};
  final _grave = <String, String>{};
  final _cursors = <String, Map<String, String>>{};
  bool _attached = false;
  bool _photoErrors = false;
  int _epoch = 0;
  Timer? _debounce;
  Future<void>? _operation;
  Future<void>? _metaTail;
  SyncState _state = SyncState.idle;
  SyncState get state => _state;
  DateTime? _lastSyncedAt;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get hasPendingChanges =>
      _dirty.isNotEmpty || _grave.isNotEmpty || _photoErrors;
  String? get _uid => AuthService.instance.viewer?.id;
  bool get _canSync =>
      SupabaseEnv.isConfigured &&
      AuthService.instance.isSignedIn &&
      _uid != null;

  Future<void> attach() async {
    if (_attached) return;
    final shadow = await _local.readMap(kShadow);
    shadow?.forEach((k, v) => _shadow[k] = '$v');
    final graves = await _local.readMap(kGrave);
    graves?.forEach((k, v) => _grave[k] = '$v');
    final cursors = await _local.readMap(kCursor);
    cursors?.forEach((k, v) {
      if (v is Map) _cursors[k] = v.map((k, v) => MapEntry('$k', '$v'));
    });
    if (!await _local.readFlag('articket.sync.hash.v2')) {
      for (final j in [
        ..._store.folders.map((f) => f.toJson()),
        ..._store.tickets.map((t) => t.toJson()),
      ]) {
        final old = Map<String, dynamic>.from(j)
          ..remove('design')
          ..remove('isFavorite');
        for (final key in ['layers', 'pageLayers']) {
          if (old[key] is String) {
            final layers = jsonDecode(old[key] as String) as List;
            for (final layer in layers) {
              (layer as Map).remove('photoKey');
            }
            old[key] = jsonEncode(layers);
          }
        }
        final legacy = md5.convert(utf8.encode(jsonEncode(old))).toString();
        if (_shadow[j['id']] == legacy) _shadow[j['id'] as String] = _hash(j);
      }
    }
    _attached = true;
    // This must happen before the first pull: an offline deletion must not be
    // resurrected just because its first debounce never completed.
    _rescan();
    await _persistMeta();
  }

  void noteChange() {
    if (!_attached || !_store.isReady) return;
    _rescan();
    unawaited(
      _persistMeta().catchError((Object e) {
        debugPrint('[sync metadata] $e');
      }),
    );
    _debounce?.cancel();
    if (_canSync) {
      _debounce = Timer(const Duration(seconds: 3), () => unawaited(syncNow()));
    }
  }

  void _rescan() {
    if (!_attached || !_store.isReady) return;
    final live = <String>{};
    void scan(String id, Map<String, dynamic> json) {
      live.add(id);
      final hash = _hash(json);
      if (hash == _shadow[id]) {
        _dirty.remove(id);
      } else {
        _dirty[id] = hash;
      }
      _grave.remove(id);
    }

    for (final f in _store.folders) {
      scan(f.id, f.toJson());
    }
    for (final t in _store.tickets) {
      scan(t.id, t.toJson());
    }
    _dirty.removeWhere((id, _) => !live.contains(id));
    for (final id in _shadow.keys) {
      if (!live.contains(id)) {
        _grave.putIfAbsent(id, () => DateTime.now().toUtc().toIso8601String());
      }
    }
  }

  Future<void> syncNow({bool full = false}) => _start(full: full);
  Future<void> pushPending() => _start(pushOnly: true);
  Future<void> _start({bool full = false, bool pushOnly = false}) {
    if (!_canSync || !_store.isReady || !_attached) return Future.value();
    if (_operation != null) return _operation!;
    final epoch = _epoch;
    final uid = _uid!;
    final run = _perform(uid, epoch, full: full, pushOnly: pushOnly);
    _operation = run;
    return run.whenComplete(() {
      if (_epoch == epoch) _operation = null;
    });
  }

  void _check(String uid, int epoch) {
    if (epoch != _epoch || uid != _uid) {
      throw StateError('Sync session changed');
    }
  }

  Future<void> _perform(
    String uid,
    int epoch, {
    required bool full,
    required bool pushOnly,
  }) async {
    _set(SyncState.syncing);
    try {
      if (full) _cursors.clear();
      _rescan();
      await _persistMeta();
      await _roundTrip(
        uid,
        epoch,
        pushOnly,
      ).timeout(const Duration(seconds: 45));
      _check(uid, epoch);
      _lastSyncedAt = DateTime.now();
      _rescan();
      await _persistMeta();
      _set(_photoErrors ? SyncState.error : SyncState.idle);
      // An edit made during an in-flight request must get its own upload.
      if (_dirty.isNotEmpty && !_photoErrors) {
        _debounce?.cancel();
        _debounce = Timer(
          const Duration(seconds: 3),
          () => unawaited(syncNow()),
        );
      }
    } catch (e) {
      if (epoch != _epoch) return;
      if (e is TimeoutException) {
        _epoch++;
        _operation = null;
      }
      _rescan();
      await _persistMeta();
      final text = e.toString();
      _set(
        e is TimeoutException ||
                text.contains('SocketException') ||
                text.contains('Failed host lookup')
            ? SyncState.offline
            : SyncState.error,
      );
    }
  }

  Future<void> _roundTrip(String uid, int epoch, bool pushOnly) async {
    if (!pushOnly) {
      await _pullTable('folders', uid, epoch);
      await _pullTable('tickets', uid, epoch);
    }
    _check(uid, epoch);
    final changed = await PosterStorage.instance.syncPhotos(
      _store.tickets,
      folders: _store.folders,
      isCurrent: () => epoch == _epoch && uid == _uid,
    );
    _check(uid, epoch);
    _photoErrors = PosterStorage.instance.lastSyncHadErrors;
    if (changed) _store.touch();
    _rescan();
    await _push(uid, epoch);
    _check(uid, epoch);
    _store.touch();
    await _store.flush();
  }

  Future<void> _pullTable(String table, String uid, int epoch) async {
    while (true) {
      _check(uid, epoch);
      final cursor = _cursors[table];
      dynamic query = sb.from(table).select().eq('user_id', uid);
      if (cursor != null) {
        final time = cursor['time']!;
        final id = cursor['id']!;
        query = query.or(
          'updated_at.gt.$time,and(updated_at.eq.$time,id.gt.$id)',
        );
      }
      final rows =
          await query.order('updated_at').order('id').limit(200) as List;
      _check(uid, epoch);
      if (rows.isEmpty) break;
      for (final value in rows) {
        final row = Map<String, dynamic>.from(value as Map);
        final id = row['id'] as String;
        if (!_dirty.containsKey(id) && !_grave.containsKey(id)) {
          if (row['deleted_at'] != null) {
            table == 'folders'
                ? _store.removeFolderQuiet(id)
                : _store.removeQuiet(id);
            _shadow.remove(id);
          } else if (table == 'folders') {
            final incoming = RemoteStore.folderFromRow(row);
            _inheritPhotos(
              incoming.pageLayers,
              _store.folderById(id)?.pageLayers ?? [],
            );
            _store.upsertFolderQuiet(incoming);
            _shadow[id] = _hash(incoming.toJson());
          } else {
            final incoming = RemoteStore.ticketFromRow(row);
            final old = _store.byId(id);
            if (old?.posterKey == incoming.posterKey) {
              incoming.posterPath = old?.posterPath;
            }
            _inheritPhotos(incoming.layers, old?.layers ?? []);
            _store.upsertQuiet(incoming);
            _shadow[id] = _hash(incoming.toJson());
          }
        }
        _cursors[table] = {'time': '${row['updated_at']}', 'id': id};
      }
      // Store the pulled rows before advancing the durable cursor.
      _store.touch();
      await _store.flush();
      await _persistMeta();
      if (rows.length < 200) break;
    }
  }

  void _inheritPhotos(List<ScrapLayer> incoming, List<ScrapLayer> previous) {
    final byId = {for (final l in previous) l.id: l};
    for (final l in incoming.where((l) => l.kind == LayerKind.photo)) {
      final old = byId[l.id];
      if (old != null && old.photoKey == l.photoKey) l.content = old.content;
    }
  }

  Future<void> _push(String uid, int epoch) async {
    // Legacy local numbers must raise server counters even if pull was nonempty.
    final top = <int, int>{};
    for (final t in _store.tickets) {
      if (t.isIssued && t.issuedSeq > (top[t.issuedYear] ?? 0)) {
        top[t.issuedYear] = t.issuedSeq;
      }
    }
    for (final e in top.entries) {
      await RemoteStore.raiseCounter(e.key, e.value);
      _check(uid, epoch);
    }
    for (final t in _store.tickets.where((t) => !t.isIssued).toList()) {
      final seq = await RemoteStore.issueSerial(t.visitedAt.year);
      _check(uid, epoch);
      if (seq == null) throw StateError('Ticket serial could not be issued');
      if (_store.byId(t.id) != t) continue;
      t.issuedYear = t.visitedAt.year;
      t.issuedSeq = seq;
    }
    _rescan();
    final folders = _store.folders;
    for (var i = 0; i < folders.length; i++) {
      final f = folders[i];
      if (!_dirty.containsKey(f.id)) continue;
      final hash = _hash(f.toJson());
      final row = RemoteStore.folderRow(f, uid, i);
      await sb.from('folders').upsert(row);
      _check(uid, epoch);
      _shadow[f.id] = hash;
      if (_store.folderById(f.id) == f && _hash(f.toJson()) == hash) {
        _dirty.remove(f.id);
      }
    }
    for (final t in _store.tickets.toList()) {
      if (!_dirty.containsKey(t.id)) continue;
      final hash = _hash(t.toJson());
      final row = RemoteStore.ticketRow(t, uid);
      await sb.from('tickets').upsert(row);
      _check(uid, epoch);
      _shadow[t.id] = hash;
      if (_store.byId(t.id) == t && _hash(t.toJson()) == hash) {
        _dirty.remove(t.id);
      }
    }
    final graves = Map<String, String>.from(_grave);
    for (final table in ['tickets', 'folders']) {
      if (graves.isEmpty) break;
      await sb
          .from(table)
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .inFilter('id', graves.keys.toList())
          .eq('user_id', uid);
      _check(uid, epoch);
    }
    if (graves.isNotEmpty) {
      await PosterStorage.instance.removeRemote(graves.keys.toList());
      _check(uid, epoch);
      for (final e in graves.entries) {
        if (_grave[e.key] == e.value) {
          _grave.remove(e.key);
          _shadow.remove(e.key);
        }
      }
    }
  }

  Future<void> adoptLocalDataThenSync() async {
    _shadow.clear();
    _grave.clear();
    _cursors.clear();
    _rescan();
    await syncNow(full: true);
  }

  Future<void> reset() async {
    _epoch++;
    _debounce?.cancel();
    _operation = null;
    await _metaTail?.catchError((Object _) {});
    _shadow.clear();
    _dirty.clear();
    _grave.clear();
    _cursors.clear();
    _lastSyncedAt = null;
    _photoErrors = false;
    for (final key in [
      kShadow,
      kDirty,
      kGrave,
      kCursor,
      'articket.sync.cursor.v1',
      'articket.sync.hash.v2',
    ]) {
      await _local.delete(key);
    }
    _set(SyncState.idle);
  }

  Future<void> flushLocalState() => _persistMeta();
  Future<void> _persistMeta() {
    final epoch = _epoch;
    final shadow = Map.of(_shadow),
        dirty = Map.of(_dirty),
        grave = Map.of(_grave);
    final cursors = {for (final e in _cursors.entries) e.key: Map.of(e.value)};
    Future<void> write() async {
      if (epoch != _epoch) return;
      await _local.write(kShadow, shadow);
      await _local.write(kDirty, dirty);
      await _local.write(kGrave, grave);
      await _local.write(kCursor, cursors);
      await _local.writeFlag('articket.sync.hash.v2', true);
    }

    final previous = _metaTail;
    late final Future<void> task;
    task =
        (previous == null
                ? write()
                : previous.catchError((Object _) {}).then((_) => write()))
            .whenComplete(() {
              if (identical(_metaTail, task)) _metaTail = null;
            });
    return _metaTail = task;
  }

  static String _hash(Map<String, dynamic> json) {
    final j = Map<String, dynamic>.from(json)
      ..remove('posterPath')
      ..remove('serial');
    for (final key in ['layers', 'pageLayers']) {
      if (j[key] is String) j[key] = RemoteStore.cloudLayers(j[key]);
    }
    return md5.convert(utf8.encode(jsonEncode(j))).toString();
  }

  void _set(SyncState value) {
    if (_state != value) {
      _state = value;
      notifyListeners();
    }
  }
}
