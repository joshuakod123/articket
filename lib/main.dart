import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_gate.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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