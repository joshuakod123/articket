import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../data/local_store.dart';
import '../data/ticket_store.dart';

/// 로그인 상태.
enum AuthStage {
  /// 아직 기기에서 읽는 중. 스플래시를 띄웁니다.
  unknown,

  /// 계정이 없거나 로그아웃 상태.
  signedOut,

  /// 로그인 됨.
  signedIn,
}

/// 로그인·회원가입·탈퇴.
///
/// ## 지금은 기기 안에서만 돕니다
///
/// 서버가 아직 없으므로 계정을 [LocalStore]에 둡니다. 비밀번호는 평문으로
/// 두지 않고 **임의 소금 + SHA-256** 으로 해싱합니다. 기기 안이라도 평문
/// 비밀번호를 남기면, 백업 파일이 새는 순간 사용자가 다른 서비스에서 쓰는
/// 비밀번호까지 같이 샙니다.
///
/// ## 서버가 생기면 어디를 바꾸나
///
/// 아래 네 메서드의 **본문만** 갈아 끼우면 됩니다. 화면은 [AuthService]의
/// [stage]와 [viewer]만 보고 있으니 손댈 필요가 없습니다.
///
/// * [signUp] → `POST /auth/signup`
/// * [signIn] → `POST /auth/login` (+ 토큰 저장)
/// * [signOut] → 토큰 폐기
/// * [deleteAccount] → `DELETE /auth/me` (+ 로컬 삭제)
///
/// ## 애플 심사에서 걸리는 자리
///
/// * **Guideline 5.1.1(v)** — 계정을 만들 수 있는 앱은 **앱 안에서** 계정을
///   영구 삭제할 수 있어야 합니다. 웹으로 보내거나 "고객센터에 문의"로
///   때우면 리젝입니다. 비활성화(deactivate)만 제공하는 것도 안 됩니다.
///   [deleteAccount]가 이 요구를 충족합니다.
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

  // ── 앱 시작 ─────────────────────────────────────

  /// 스플래시에서 한 번 부릅니다.
  Future<void> restore() async {
    final session = await _local.readMap(LocalStore.kSession);
    final account = await _local.readMap(LocalStore.kAccount);

    if (session != null && account != null && session['email'] == account['email']) {
      _viewer = Viewer.fromJson(account);
      _stage = AuthStage.signedIn;
    } else {
      _stage = AuthStage.signedOut;
    }
    notifyListeners();
  }

  // ── 회원가입 / 로그인 ────────────────────────────

  /// 새 계정. 이미 계정이 있는 기기면 [AuthFailure.alreadyExists].
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final e = email.trim().toLowerCase();
    if (!_looksLikeEmail(e)) return AuthResult.fail(AuthFailure.badEmail);
    if (password.length < 8) return AuthResult.fail(AuthFailure.weakPassword);
    if (name.trim().isEmpty) return AuthResult.fail(AuthFailure.emptyName);

    final existing = await _local.readMap(LocalStore.kAccount);
    if (existing != null && existing['email'] == e) {
      return AuthResult.fail(AuthFailure.alreadyExists);
    }

    final salt = _newSalt();
    final viewer = Viewer(
      email: e,
      name: name.trim(),
      joinedAt: DateTime.now(),
    );

    await _local.write(LocalStore.kAccount, {
      ...viewer.toJson(),
      'salt': salt,
      'hash': _hash(password, salt),
    });
    await _local.write(LocalStore.kSession, {
      'email': e,
      'at': DateTime.now().toIso8601String(),
    });

    _viewer = viewer;
    _stage = AuthStage.signedIn;
    notifyListeners();
    return AuthResult.ok();
  }

  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final e = email.trim().toLowerCase();
    final account = await _local.readMap(LocalStore.kAccount);

    // 이메일이 없는 경우와 비밀번호가 틀린 경우를 **구분해서 알려주지 않습니다.**
    // "그 이메일은 가입돼 있음"을 알려주는 것 자체가 계정 열거 공격의 실마리입니다.
    if (account == null ||
        account['email'] != e ||
        _hash(password, account['salt'] as String? ?? '') != account['hash']) {
      return AuthResult.fail(AuthFailure.wrongCredentials);
    }

    await _local.write(LocalStore.kSession, {
      'email': e,
      'at': DateTime.now().toIso8601String(),
    });

    _viewer = Viewer.fromJson(account);
    _stage = AuthStage.signedIn;
    notifyListeners();
    return AuthResult.ok();
  }

  /// 로그아웃. **기록은 지우지 않습니다.** 다시 로그인하면 그대로 있습니다.
  Future<void> signOut() async {
    await _local.delete(LocalStore.kSession);
    _viewer = null;
    _stage = AuthStage.signedOut;
    notifyListeners();
  }

  // ── 프로필 ──────────────────────────────────────

  Future<void> rename(String name) async {
    final v = _viewer;
    if (v == null || name.trim().isEmpty) return;

    final account = await _local.readMap(LocalStore.kAccount);
    if (account == null) return;

    final next = v.copyWith(name: name.trim());
    await _local.write(LocalStore.kAccount, {...account, ...next.toJson()});
    _viewer = next;
    notifyListeners();
  }

  Future<AuthResult> changePassword({
    required String current,
    required String next,
  }) async {
    final account = await _local.readMap(LocalStore.kAccount);
    if (account == null) return AuthResult.fail(AuthFailure.wrongCredentials);
    if (_hash(current, account['salt'] as String? ?? '') != account['hash']) {
      return AuthResult.fail(AuthFailure.wrongCredentials);
    }
    if (next.length < 8) return AuthResult.fail(AuthFailure.weakPassword);

    final salt = _newSalt();
    await _local.write(LocalStore.kAccount, {
      ...account,
      'salt': salt,
      'hash': _hash(next, salt),
    });
    return AuthResult.ok();
  }

  // ── 탈퇴 ────────────────────────────────────────

  /// 계정과 **기기에 남은 모든 기록**을 지웁니다. 되돌릴 수 없습니다.
  ///
  /// 순서가 중요합니다. 데이터를 먼저 지우고 계정을 마지막에 지웁니다.
  /// 반대로 하면, 중간에 앱이 죽었을 때 "계정은 없는데 기록만 남은" 상태가
  /// 됩니다. 그 기록은 누구도 다시 열 수 없고 지울 수도 없습니다.
  ///
  /// 서버가 생기면 이 자리에 `DELETE /auth/me`를 먼저 넣고, 성공 응답을
  /// 받은 뒤에 로컬을 지우세요. 로컬만 지우면 서버에 데이터가 남습니다.
  Future<AuthResult> deleteAccount({required String password}) async {
    final account = await _local.readMap(LocalStore.kAccount);
    if (account == null) return AuthResult.fail(AuthFailure.wrongCredentials);

    // 마지막 확인. 잠금 해제된 기기를 남이 집어 든 경우를 막습니다.
    if (_hash(password, account['salt'] as String? ?? '') != account['hash']) {
      return AuthResult.fail(AuthFailure.wrongCredentials);
    }

    await TicketStore.instance.wipe(); // 티켓·서류철·발권 대장
    await _local.wipe(); // 계정·세션·설정까지 남김없이

    _viewer = null;
    _stage = AuthStage.signedOut;
    notifyListeners();
    return AuthResult.ok();
  }

  // ── 자잘한 것 ───────────────────────────────────

  static bool _looksLikeEmail(String s) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);

  static String _newSalt() {
    final r = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  static String _hash(String password, String salt) =>
      sha256.convert(utf8.encode('$salt::$password')).toString();
}

/// 로그인한 사람.
@immutable
class Viewer {
  const Viewer({
    required this.email,
    required this.name,
    required this.joinedAt,
  });

  final String email;
  final String name;
  final DateTime joinedAt;

  Viewer copyWith({String? name}) => Viewer(
    email: email,
    name: name ?? this.name,
    joinedAt: joinedAt,
  );

  Map<String, dynamic> toJson() => {
    'email': email,
    'name': name,
    'joinedAt': joinedAt.toIso8601String(),
  };

  factory Viewer.fromJson(Map<String, dynamic> j) => Viewer(
    email: j['email'] as String? ?? '',
    name: j['name'] as String? ?? '이름 없는 관람자',
    joinedAt:
    DateTime.tryParse(j['joinedAt'] as String? ?? '') ?? DateTime.now(),
  );
}

enum AuthFailure {
  badEmail('이메일 주소를 다시 확인해주세요'),
  weakPassword('비밀번호는 8자 이상이어야 합니다'),
  emptyName('부를 이름이 필요합니다'),
  alreadyExists('이 기기에 이미 계정이 있습니다'),
  wrongCredentials('이메일이나 비밀번호가 맞지 않습니다');

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