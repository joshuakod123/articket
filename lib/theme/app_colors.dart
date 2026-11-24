import 'package:flutter/material.dart';

/// Interface tokens are independent of the paper used by saved collectibles.
class AppColors {
  AppColors._();
  static const bg = Color(0xFFF9F9F6);
  static const bgDeep = Color(0xFFF0F0ED);
  static const ink = Color(0xFF20221F);
  static const inkSoft = Color(0xFF696C66);
  static const line = Color(0xFFE2E3DE);
  static const accent = Color(0xFFEC654C);
  static const accentDark = Color(0xFFB33E29);
  static const lavender = Color(0xFFEAE4F5);
  static const butter = Color(0xFFF3E8AF);
  static const sage = Color(0xFFDCE4CD);
  static const blue = Color(0xFF2551E8);
  static const surface = Color(0xFFFFFFFF);
  static const danger = Color(0xFFBB3929);
  // Paper/art tokens retain their meaning; changing a button never recolors art.
  static const stock = Color(0xFFF6F0E2);
  static const stockLight = Color(0xFFFCF8EE);
  static const pulp = Color(0xFFC7BBA2);
  static const kraft = Color(0xFFB08F5C);
  static const kraftDeep = Color(0xFF8E6F42);
  static const oxblood = Color(0xFF6B1F1A);
  static const oxbloodDim = Color(0xFF471310);
  static const foil = Color(0xFF8C7134);
  static const dymo = Color(0xFF1E1A15);
  static const tabColors = <Color>[
    lavender,
    butter,
    sage,
    Color(0xFFDCEAF5),
    Color(0xFFF1DCD7),
    Color(0xFF424740),
    Color(0xFF6B1F1A),
    Color(0xFFB08F5C),
  ];
  static const holo = <Color>[
    Color(0x66FF9BB0),
    Color(0x668FD8FF),
    Color(0x66C8FFB0),
    Color(0x66FFE59B),
  ];
}
