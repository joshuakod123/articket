import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/archive_screen.dart';
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
      home: const ArchiveScreen(),
    );
  }
}