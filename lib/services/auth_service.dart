import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/local_store.dart';
import '../data/serial.dart';
import '../data/supabase_env.dart';
import '../data/sync_service.dart';
import '../data/ticket_store.dart';
import 'guide_service.dart';

/// 로그인 상태.
enum AuthStage {
  /// 아직 읽는 중. 스플래시를 띄웁니다.
  unknown,

  /// 계정이 없거나 로그아웃 상태.
  signedOut,

  /// 로그인 됨.
  signedIn,
}

/// 로그인·회원가입·탈퇴 — **Supabase 판**.
///
/// ## 바깥에서 보면 달라진 게 없습니다
///
/// [stage] · [viewer] · [signUp] · [signIn] · [signOut] · [rename] ·
/// [changePassword] · [deleteAccount] · [knownEmail] 의 시그니처가 그대로입니다.
/// `auth_screen.dart`, `settings_screen.dart`, `delete_account_screen.dart`,
/// `app_gate.dart` 를 한 줄도 안 고쳐도 됩니다.
///
/// ## 안에서 달라진 것 넷
///
/// **1. 계정이 기기에 하나가 아닙니다.** [AuthFailure.alreadyExists] 는 이제
///    "이 기기엔 이미 계정이 있어요"가 아니라 "이미 가입된 이메일"입니다.
///    단, 서버 기본 설정은 계정 열거를 막으려고 **가입 성공처럼 응답**하므로
///    이 실패는 실제로는 잘 안 뜹니다. 그게 맞습니다.
///
/// **2. 비밀번호 해싱을 우리가 안 합니다.** `salt + SHA-256` 을 걷어냅니다.
///    기기 저장용으로는 괜찮았지만 서버 저장용으로는 부족합니다(GPU 로 초당
///    수십억 번 돌아갑니다). Supabase 는 bcrypt 를 씁니다.
///
/// **3. 로그인 실패 구분은 여전히 안 합니다.** 서버가 401 을 어떻게 쪼개주든
///    화면에는 [AuthFailure.wrongCredentials] 하나로 내립니다. 그 이메일이
///    가입돼 있다는 사실 자체가 계정 열거 공격의 실마리입니다.
///
/// **4. 오프라인이 새 실패 사유입니다.** 세션은 기기에 남으므로 [restore] 는
///    비행기 모드에서도 성공합니다. 하지만 [signIn] 은 네트워크가 필요합니다.
///    이걸 "비밀번호가 틀렸다"로 보여주면 사용자가 멀쩡한 비밀번호를 바꿉니다.
///
/// ## 애플 심사에서 걸리는 자리
///
/// * **Guideline 5.1.1(v)** — 계정을 만들 수 있는 앱은 **앱 안에서** 계정을
///   영구 삭제할 수 있어야 합니다. [deleteAccount] 가 이 요구를 충족합니다.
/// * 나중에 구글/카카오/네이버 로그인을 붙이면 **Sign in with Apple** 도
///   같이 제공해야 합니다(4.8). 지금은 이메일 하나뿐이라 해당 없음.
class AuthService extends ChangeNotifier {
  AuthService._();

  static final AuthService instance = AuthService._();

  final _local = LocalStore.instance;

  AuthStage _stage = AuthStage.unknown;
  AuthStage get stage => _stage;

  Viewer? _viewer;

  /// 지금 로그인한 사람. 로그아웃 상태면 null.
  Viewer? get viewer => _viewer;

  bool get isSignedIn => _stage == AuthStage.signedIn;

  StreamSubscription<AuthState>? _sub;

  // ── 앱 시작 ─────────────────────────────────────

  /// 스플래시에서 한 번. `SupabaseEnv.init()` 이 먼저 끝나 있어야 합니다.
  Future<void> restore() async {
    if (!SupabaseEnv.isConfigured) {
      // 접속값이 없으면 로그인 자체가 불가능합니다. 계정이 서버로 갔으니까요.
      _stage = AuthStage.signedOut;
      notifyListeners();
      return;
    }

    // 토큰 만료 · 비밀번호 변경 · 다른 곳에서의 로그아웃을 여기서 받습니다.
    _sub ??= sb.auth.onAuthStateChange.listen((s) {
      if (s.session == null && _stage == AuthStage.signedIn) {
        _viewer = null;
        _stage = AuthStage.signedOut;
        notifyListeners();
      }
    });

    final user = sb.auth.currentUser;
    if (user == null) {
      _stage = AuthStage.signedOut;
      notifyListeners();
      return;
    }

    // 캐시된 프로필로 **먼저** 화면을 띄웁니다. 네트워크를 기다리지 않습니다.
    // 서랍이 열리는 데 서버가 끼면 이 앱은 팔던 것과 다른 물건이 됩니다.
    final cached = await _local.readMap(LocalStore.kAccount);
    _viewer = (cached != null && cached['id'] == user.id)
        ? Viewer.fromJson(cached)
        : Viewer.fromUser(user);
    _stage = AuthStage.signedIn;
    notifyListeners();

    unawaited(_refreshProfile()); // 이름·플랜이 바뀌었으면 조용히 갱신
    unawaited(SyncService.instance.syncNow());
  }

  // ── 회원가입 / 로그인 ────────────────────────────

  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final e = email.trim().toLowerCase();
    if (!_looksLikeEmail(e)) return AuthResult.fail(AuthFailure.badEmail);
    if (password.length < 8) return AuthResult.fail(AuthFailure.weakPassword);
    if (name.trim().isEmpty) return AuthResult.fail(AuthFailure.emptyName);
    if (!SupabaseEnv.isConfigured) {
      return AuthResult.fail(AuthFailure.notConfigured);
    }

    try {
      // `data` 는 auth.users.raw_user_meta_data 로 들어가고,
      // handle_new_user() 트리거가 그걸 읽어 profiles 행을 만듭니다.
      final res = await sb.auth.signUp(
        email: e,
        password: password,
        data: {'name': name.trim()},
      );

      // 이메일 확인이 켜져 있으면 세션이 안 옵니다. 이때 로그인된 척하면
      // 다음 화면에서 전부 401 이 납니다.
      if (res.session == null || res.user == null) {
        return AuthResult.fail(AuthFailure.needsEmailConfirm);
      }

      await _adopt(res.user!, fallbackName: name.trim());

      // ── 새 계정은 **빈 서랍**에서 시작합니다 ──
      //
      // 예전에는 여기서 `adoptLocalDataThenSync()` 를 불러, 이 기기에 남아
      // 있던 기록을 새 계정 것으로 입양했습니다. 로그인 없이 쓸 수 있는
      // 앱이라면 맞는 처리입니다. **그런데 이 앱은 로그인해야 들어옵니다**
      // (`AppGate` 가 `signedOut` 이면 `AuthScreen` 만 띄웁니다).
      //
      // 그러면 가입 시점에 기기에 남아 있는 기록은 둘 중 하나뿐입니다.
      //
      //   (a) 구버전이 깔아 둔 **예시 데이터** — 남의 전시
      //   (b) 앞서 로그아웃한 **다른 사람의 기록** — 진짜 남의 기록
      //
      // 어느 쪽도 이 계정의 것이 아닙니다. (b)는 그냥 화면이 이상한 정도가
      // 아니라, 남의 관람 기록·사진·한 줄 평이 새 계정의 서버 계정으로
      // 통째로 업로드되는 **사고**입니다. 그래서 입양하지 않고 비웁니다.
      //
      // 로그아웃한 사람의 기록은 사라지지 않습니다. 그 사람이 다시
      // 로그인하면 서버에서 그대로 내려옵니다(`signOut` 이 나가기 전에
      // 밀어 올립니다).
      await TicketStore.instance.wipe();

      // 새 사람이니 안내도 처음부터.
      await GuideService.instance.reset();

      unawaited(SyncService.instance.syncNow(full: true));
      return AuthResult.ok();
    } on AuthException catch (err) {
      return AuthResult.fail(_mapAuthError(err));
    } catch (err) {
      return AuthResult.fail(_mapNetworkError(err));
    }
  }

  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final e = email.trim().toLowerCase();
    if (!SupabaseEnv.isConfigured) {
      return AuthResult.fail(AuthFailure.notConfigured);
    }

    try {
      final res = await sb.auth.signInWithPassword(email: e, password: password);
      final user = res.user;
      if (user == null) return AuthResult.fail(AuthFailure.wrongCredentials);

      // **다른 계정으로 갈아탄 경우** 이 기기의 로컬 기록은 남의 것입니다.
      // 지우고 서버에서 새로 받습니다. 안 지우면 A 의 티켓이 B 의 서랍에 섞입니다.
      final previous = await _local.readMap(LocalStore.kAccount);
      final switched = previous != null &&
          previous['id'] is String &&
          previous['id'] != user.id;

      await _adopt(user);

      if (switched) {
        await TicketStore.instance.wipe(); // 안에서 SyncService.reset() 먼저
        await TicketStore.instance.load();
      }
      unawaited(SyncService.instance.syncNow(full: true));
      return AuthResult.ok();
    } on AuthException catch (_) {
      // 서버가 뭐라 하든 하나로 내립니다.
      return AuthResult.fail(AuthFailure.wrongCredentials);
    } catch (err) {
      return AuthResult.fail(_mapNetworkError(err));
    }
  }

  /// 로그아웃. **기록은 지우지 않습니다.** 다시 로그인하면 그대로 있습니다.
  ///
  /// 단, 나가기 전에 **아직 안 올라간 것을 밀어 올립니다.** 이걸 안 하면
  /// 로그아웃하고 앱을 지운 사용자의 마지막 기록이 통째로 사라집니다.
  Future<void> signOut() async {
    if (SupabaseEnv.isConfigured) {
      try {
        await SyncService.instance
            .pushPending()
            .timeout(const Duration(seconds: 8));
      } catch (_) {}
      try {
        await sb.auth.signOut();
      } catch (_) {
        // 네트워크가 없어도 로그아웃은 되어야 합니다. 로컬 세션만 끊습니다.
        try {
          await sb.auth.signOut(scope: SignOutScope.local);
        } catch (_) {}
      }
    }
    await _local.delete(LocalStore.kSession);
    _viewer = null;
    _stage = AuthStage.signedOut;
    notifyListeners();
  }

  /// 마지막으로 로그인한 이메일. 로그인 화면 자동 채우기용.
  ///
  /// 비밀번호는 절대 돌려주지 않습니다. 갖고 있지도 않지만, 갖고 있더라도
  /// 화면으로 올려보낼 값이 아닙니다.
  Future<String?> knownEmail() async {
    final account = await _local.readMap(LocalStore.kAccount);
    final email = account?['email'];
    return email is String && email.isNotEmpty ? email : null;
  }

  // ── 프로필 ──────────────────────────────────────

  Future<void> rename(String name) async {
    final v = _viewer;
    final n = name.trim();
    if (v == null || n.isEmpty) return;

    // 낙관적 갱신. 화면은 즉시 바뀌고, 서버가 실패해도 다음 동기화가 고칩니다.
    _viewer = v.copyWith(name: n);
    await _cache(_viewer!);
    notifyListeners();

    try {
      await sb.from('profiles').update({'name': n}).eq('id', v.id);
      await sb.auth.updateUser(UserAttributes(data: {'name': n}));
    } catch (_) {}
  }

  Future<AuthResult> changePassword({
    required String current,
    required String next,
  }) async {
    final v = _viewer;
    if (v == null) return AuthResult.fail(AuthFailure.wrongCredentials);
    if (next.length < 8) return AuthResult.fail(AuthFailure.weakPassword);

    // Supabase 의 updateUser 는 **현재 비밀번호를 묻지 않습니다.** 잠금 해제된
    // 남의 폰으로 비밀번호를 갈아치울 수 있다는 뜻입니다. 재인증을 우리가 겁니다.
    if (!await _reauthenticate(v.email, current)) {
      return AuthResult.fail(AuthFailure.wrongCredentials);
    }

    try {
      await sb.auth.updateUser(UserAttributes(password: next));
      return AuthResult.ok();
    } on AuthException catch (err) {
      return AuthResult.fail(_mapAuthError(err));
    } catch (err) {
      return AuthResult.fail(_mapNetworkError(err));
    }
  }

  // ── 탈퇴 ────────────────────────────────────────

  /// 계정과 **서버·기기 양쪽의 모든 기록**을 지웁니다. 되돌릴 수 없습니다.
  ///
  /// 순서가 예전과 뒤집혔습니다. 이전 버전 문서에 "서버가 생기면
  /// `DELETE /auth/me` 를 **먼저** 넣고 성공 응답을 받은 뒤에 로컬을 지우세요"
  /// 라고 적어뒀습니다. 그대로 합니다.
  ///
  /// 로컬을 먼저 지우면, 서버 호출이 실패했을 때 사용자는 "지워졌다"고 믿고
  /// 앱을 삭제합니다. 그리고 그 데이터는 서버에 영원히 남습니다. 앱 안에서
  /// 다시 지울 방법도 없습니다 — 심사 리젝 사유이자, 그냥 약속을 어기는 겁니다.
  Future<AuthResult> deleteAccount({required String password}) async {
    final v = _viewer;
    if (v == null) return AuthResult.fail(AuthFailure.wrongCredentials);

    // 1. 마지막 확인. 잠금 해제된 기기를 남이 집어 든 경우를 막습니다.
    if (!await _reauthenticate(v.email, password)) {
      return AuthResult.fail(AuthFailure.wrongCredentials);
    }

    // 2. 서버. 사진 → profiles/folders/tickets(cascade) → auth.users 순.
    try {
      final res = await sb.functions.invoke('delete-account');
      if (res.status != 200) return AuthResult.fail(AuthFailure.serverError);
    } catch (err) {
      return AuthResult.fail(
          _mapNetworkError(err, fallback: AuthFailure.serverError));
    }

    // 3. 성공을 받은 뒤에야 기기를 비웁니다.
    await TicketStore.instance.wipe(); // SyncService.reset() · 사진 정리 포함
    await _local.wipe(); // 계정·세션·설정까지 남김없이
    try {
      await sb.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}

    _viewer = null;
    _stage = AuthStage.signedOut;
    notifyListeners();
    return AuthResult.ok();
  }

  // ── 안쪽 ────────────────────────────────────────

  /// 로그인 성공 뒤 공통 처리.
  Future<void> _adopt(User user, {String? fallbackName}) async {
    _viewer = Viewer.fromUser(user, fallbackName: fallbackName);
    _stage = AuthStage.signedIn;
    await _cache(_viewer!);
    await _local.write(LocalStore.kSession, {
      'id': user.id,
      'email': user.email ?? '',
      'at': DateTime.now().toIso8601String(),
    });
    notifyListeners();
    await _refreshProfile();
  }

  /// profiles 행에서 회원 번호·플랜을 받아 옵니다.
  ///
  /// 트리거가 방금 만든 행이라 [signUp] 직후에는 아주 드물게 아직 없을 수
  /// 있습니다. 실패해도 조용히 넘어갑니다 — 다음 실행에서 채워집니다.
  Future<void> _refreshProfile() async {
    final v = _viewer;
    if (v == null) return;
    try {
      final row = await sb
          .from('profiles')
          .select('name, joined_at, member_year, member_no, plan')
          .eq('id', v.id)
          .maybeSingle();
      if (row == null) return;

      _viewer = v.copyWith(
        name: row['name'] as String?,
        joinedAt: DateTime.tryParse(row['joined_at'] as String? ?? ''),
        memberYear: row['member_year'] as int?,
        memberNo: row['member_no'] as int?,
        plan: row['plan'] as String?,
      );
      await _cache(_viewer!);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _cache(Viewer v) => _local.write(LocalStore.kAccount, v.toJson());

  /// 비밀번호를 다시 받아 확인합니다. 같은 계정이라 세션은 그대로입니다.
  Future<bool> _reauthenticate(String email, String password) async {
    if (password.isEmpty) return false;
    try {
      final res =
      await sb.auth.signInWithPassword(email: email, password: password);
      return res.user != null;
    } catch (_) {
      return false;
    }
  }

  static bool _looksLikeEmail(String s) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);

  /// 서버 오류를 화면 문구로.
  ///
  /// `AuthException` 의 필드 이름은 gotrue 버전마다 조금씩 달라서
  /// (`code` 가 없던 시절이 있습니다) **[AuthException.message] 만** 봅니다.
  /// 문자열 매칭이 촌스럽지만, 여기가 컴파일 에러의 단골 자리입니다.
  static AuthFailure _mapAuthError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('already registered') || msg.contains('already exists')) {
      return AuthFailure.alreadyExists;
    }
    if (msg.contains('password should be') || msg.contains('weak password')) {
      return AuthFailure.weakPassword;
    }
    if (msg.contains('rate limit') || msg.contains('too many')) {
      return AuthFailure.tooManyAttempts;
    }
    return AuthFailure.wrongCredentials;
  }

  static AuthFailure _mapNetworkError(Object e, {AuthFailure? fallback}) {
    if (e is SocketException || e is TimeoutException) {
      return AuthFailure.offline;
    }
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('Failed host lookup')) {
      return AuthFailure.offline;
    }
    return fallback ?? AuthFailure.serverError;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// 로그인한 사람.
@immutable
class Viewer {
  const Viewer({
    required this.id,
    required this.email,
    required this.name,
    required this.joinedAt,
    this.memberYear = 0,
    this.memberNo = 0,
    this.plan = 'basic',
  });

  /// Supabase auth uid. 모든 행의 `user_id` 가 이 값입니다.
  final String id;
  final String email;
  final String name;
  final DateTime joinedAt;

  /// 회원 번호. **서버가 뽑습니다.**
  ///
  /// 예전에는 `TicketStore.memberSerialText` 가
  /// `joinedYear.hashCode % 9000 + 1` 로 만들었습니다. 그러면 같은 해에 시작한
  /// 사람이 전부 같은 번호를 받고, 앱을 지웠다 깔면 번호가 바뀝니다.
  /// 회원 번호는 바뀌면 안 되는 값입니다. 이제 `profiles.member_no` 입니다.
  final int memberYear;
  final int memberNo;

  final String plan;

  bool get isPro => plan == 'pro';

  /// `M-2025-0006`. 서버 번호가 아직 없으면 자리표시를 냅니다.
  String get memberSerialText =>
      memberNo > 0 ? memberSerial(since: memberYear, no: memberNo) : 'M-0000-0000';

  Viewer copyWith({
    String? name,
    DateTime? joinedAt,
    int? memberYear,
    int? memberNo,
    String? plan,
  }) =>
      Viewer(
        id: id,
        email: email,
        name: name ?? this.name,
        joinedAt: joinedAt ?? this.joinedAt,
        memberYear: memberYear ?? this.memberYear,
        memberNo: memberNo ?? this.memberNo,
        plan: plan ?? this.plan,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'joinedAt': joinedAt.toIso8601String(),
    'memberYear': memberYear,
    'memberNo': memberNo,
    'plan': plan,
  };

  factory Viewer.fromJson(Map<String, dynamic> j) => Viewer(
    id: j['id'] as String? ?? '',
    email: j['email'] as String? ?? '',
    name: j['name'] as String? ?? '이름 없음',
    joinedAt:
    DateTime.tryParse(j['joinedAt'] as String? ?? '') ?? DateTime.now(),
    memberYear: j['memberYear'] as int? ?? 0,
    memberNo: j['memberNo'] as int? ?? 0,
    plan: j['plan'] as String? ?? 'basic',
  );

  factory Viewer.fromUser(User u, {String? fallbackName}) {
    final meta = (u.userMetadata?['name'] as String?)?.trim();
    return Viewer(
      id: u.id,
      email: u.email ?? '',
      name: (meta != null && meta.isNotEmpty) ? meta : (fallbackName ?? '이름 없음'),
      joinedAt: DateTime.tryParse(u.createdAt) ?? DateTime.now(),
    );
  }
}

enum AuthFailure {
  badEmail('이메일 주소를 다시 봐주세요'),
  weakPassword('8자 이상으로 해주세요'),
  emptyName('이름을 적어주세요'),
  alreadyExists('이미 가입된 이메일이에요'),
  wrongCredentials('이메일이나 비밀번호가 맞지 않아요'),

  // ── 서버가 생기면서 늘어난 것들 ──
  needsEmailConfirm('보내드린 메일의 링크를 눌러주세요'),
  offline('연결이 끊겼어요. 잠시 뒤 다시 시도해 주세요'),
  tooManyAttempts('잠시 뒤에 다시 시도해 주세요'),
  serverError('지금은 처리하지 못했어요. 잠시 뒤 다시 시도해 주세요'),
  notConfigured('서버 설정이 빠졌어요');

  const AuthFailure(this.message);

  final String message;
}

@immutable
class AuthResult {
  const AuthResult._(this.failure);

  factory AuthResult.ok() => const AuthResult._(null);

  factory AuthResult.fail(AuthFailure f) => AuthResult._(f);

  final AuthFailure? failure;

  bool get isOk => failure == null;

  String get message => failure?.message ?? '';
}