import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase 접속값.
///
/// ## 우선순위
///
/// 1. `--dart-define` 으로 넣은 값 (권장)
/// 2. 아래 [_fallbackUrl] · [_fallbackAnonKey] 에 직접 적은 값
///
/// ## anon 키를 소스에 적어도 되나?
///
/// **RLS 를 빠짐없이 켰다면 됩니다.** anon 키는 "누구세요"를 말할 뿐,
/// "무엇을 볼 수 있는지"는 전부 RLS 정책이 정합니다. Supabase 가 이 키를
/// 웹 프런트엔드에 그대로 박아 쓰라고 문서에 적어둔 이유입니다.
///
/// 다만 두 가지를 감수하는 겁니다.
///
/// * **정책 하나를 빠뜨린 테이블은 그 키로 전부 읽힙니다.** 마이그레이션에
///   `alter table ... enable row level security` 를 전부 넣어둔 이유입니다.
///   나중에 테이블을 추가할 때 이걸 잊으면 그 순간 공개됩니다.
/// * 키를 회전하려면 **앱을 새로 빌드해서 스토어 심사를 다시 받아야** 합니다.
///
/// 그래서 개발 중에는 fallback 에 적어두고 편하게 쓰다가, 스토어에 올릴
/// 빌드에서는 `--dart-define` 으로 넘기는 걸 권합니다.
///
/// ⚠ **service_role 키는 절대 여기 적지 마세요.** 그건 RLS 를 통째로
///   무시하는 마스터 키입니다. APK 를 풀면 그대로 나옵니다.
///   그 키가 필요한 작업(계정 삭제)만 Edge Function 으로 뺀 이유입니다.
class SupabaseEnv {
  const SupabaseEnv._();

  // ── 여기에 붙여넣어도 됩니다 (Settings → API) ──────────────────
  //
  // 붙여넣을 거면 `.gitignore` 는 못 씁니다(소스에 박히니까). 공개 레포라면
  // 아래는 비워두고 --dart-define 을 쓰세요.
  static const _fallbackUrl = 'https://cukfijaxayfnimrgfinq.supabase.co';      // 예: 'https://abcdefgh.supabase.co'
  static const _fallbackAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN1a2ZpamF4YXlmbmltcmdmaW5xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc2NjY4ODQsImV4cCI6MjEwMzI0Mjg4NH0.bmj7B8Mihxt5NnEwtncIY9cig24jjtZHQVO5uOqaI0o';  // 예: 'eyJhbGciOiJIUzI1NiIsInR5cCI6...'

  static const _defineUrl = String.fromEnvironment('SUPABASE_URL');
  static const _defineAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get url => _defineUrl.isNotEmpty ? _defineUrl : _fallbackUrl;
  static String _normalize(String raw) {
    var u = raw.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    for (final tail in const ['/rest/v1', '/auth/v1', '/storage/v1', '/functions/v1']) {
      if (u.endsWith(tail)) u = u.substring(0, u.length - tail.length);
    }
    return u;
  }

  static String get anonKey =>
      _defineAnonKey.isNotEmpty ? _defineAnonKey : _fallbackAnonKey;

  /// 접속값이 들어왔는지.
  ///
  /// 여기서 예외를 던지면 키를 안 넣은 빌드가 스플래시에서 죽습니다.
  /// 대신 이 값을 false 로 두고 동기화를 조용히 꺼둡니다.
  ///
  /// ⚠ **단, 이 값이 false 면 로그인 자체가 불가능합니다.** 계정이 서버로
  ///   옮겨갔기 때문입니다. 로그인 화면에서 "서버 설정이 빠졌어요"가 뜬다면
  ///   키가 안 들어온 것입니다. (`flutter test` 는 이 경로를 타지만, 테스트는
  ///   RootShell 을 직접 물리므로 로그인을 지나지 않습니다)
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// `main()` 에서 `runApp` 앞에 한 번.
  static Future<void> init() async {
    if (!isConfigured) return;
    // 세션 유지·자동 갱신은 기본값입니다. 옵션을 따로 넘기지 않는 이유는
    // 버전마다 필드 이름이 조금씩 달라 컴파일 에러의 단골 자리이기 때문입니다.
    await Supabase.initialize(url: url, anonKey: anonKey);
  }
}

/// 짧게 쓰려고 둔 별칭. 설정이 없으면 던집니다(부르는 쪽이 먼저 확인할 것).
SupabaseClient get sb => Supabase.instance.client;