import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'app_gate.dart';
import 'data/supabase_env.dart'; // ← 이게 빠져 있었습니다
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Supabase 를 켭니다. **`AuthService.restore()` 보다 먼저여야 합니다.**
  //
  // 실패해도 던지지 않습니다. 접속값이 없거나 초기화가 깨져도 앱은 로컬
  // 전용으로 계속 떠야 합니다 — 서랍이 안 열리는 것보다 동기화가 안 되는
  // 쪽이 훨씬 낫습니다.
  //
  // ⚠ 플러그인을 새로 넣은 뒤에는 hot restart 가 아니라 **완전히 껐다 켜세요.**
  //   hot restart 만 하면 MissingPluginException 으로 이 catch 에 걸려,
  //   에러도 안 보이는데 동기화만 조용히 꺼진 상태가 됩니다.
  try {
    await SupabaseEnv.init();
  } catch (e, s) {
    debugPrint('Supabase 초기화 실패 — 로컬 전용으로 계속합니다: $e\n$s');
  }

  runApp(const ArticketApp());
}

class ArticketApp extends StatelessWidget {
  const ArticketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Articket',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      // 예전에는 곧장 RootShell 이었습니다. 이제 [AppGate]가
      // 스플래시 → 로그인 → 본 화면을 상태에 따라 갈아 끼웁니다.
      home: const AppGate(),
    );
  }
}