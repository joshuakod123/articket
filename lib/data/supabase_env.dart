import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase 접속값.
///
/// ## 키를 소스에 박지 않는 이유
///
/// anon 키는 "공개해도 되는 키"로 소개되지만, 그건 **RLS 를 빠짐없이 켰을 때**
/// 얘기입니다. 정책 하나를 빠뜨린 테이블이 있으면 그 키로 전부 읽힙니다.
/// 그리고 프로젝트를 옮기거나 키를 회전할 때 소스에 박혀 있으면 재빌드해야
/// 합니다. `--dart-define` 이면 CI 변수만 바꾸면 됩니다.
///
/// ```bash
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
/// ```
///
/// 반복이 귀찮으면 `--dart-define-from-file=env.json` 을 쓰고 그 파일을
/// `.gitignore` 에 넣으세요.
class SupabaseEnv {
  const SupabaseEnv._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// 접속값이 들어왔는지.
  ///
  /// 여기서 예외를 던지면 키를 안 넣은 개발 빌드가 스플래시에서 죽습니다.
  /// 이 앱은 서버 없이도 서랍이 열려야 하므로, 대신 이 값을 false 로 두고
  /// 동기화만 조용히 꺼둡니다. 예전처럼 로컬 전용으로 계속 돌아갑니다.
  /// (`flutter test` 도 이 경로를 탑니다 — 그래서 테스트를 안 고쳐도 됩니다)
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// `main()` 에서 `runApp` 앞에 한 번.
  static Future<void> init() async {
    if (!isConfigured) return;
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      // 세션을 기기에 남깁니다. 비행기 모드로 앱을 켜도 로그인 상태가 유지되고
      // AppGate 가 곧바로 RootShell 로 갑니다. 이게 로컬 우선의 전제입니다.
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: true),
    );
  }
}

/// 짧게 쓰려고 둔 별칭. 설정이 없으면 던집니다(부르는 쪽이 먼저 확인할 것).
SupabaseClient get sb => Supabase.instance.client;