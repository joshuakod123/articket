import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_text.dart';

class AppTheme {
  AppTheme._();

  static ThemeData build() {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.ink,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.oxblood,
        secondary: AppColors.foil,
        surface: AppColors.ink,
        onSurface: AppColors.stock,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.stock,
        displayColor: AppColors.stock,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.stock, size: 20),
        titleTextStyle: AppText.eyebrow(color: AppColors.stock),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: const DividerThemeData(
        color: AppColors.inkSoft,
        thickness: 1,
        space: 1,
      ),
      // 접근성: 모션 축소 설정을 존중하기 위한 기본 페이지 전환.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}