import 'package:flutter/material.dart';

/// Articket 팔레트 — "빛바랜 서류철" 웜 톤.
///
/// 차가운 화이트를 걷어내고, 오래된 양장본 속지와 마닐라 서류철의
/// 누런 기운으로 통일했습니다. 화면 어디를 잘라도 종이 위입니다.
class AppColors {
  AppColors._();

  // ── 바탕 ─────────────────────────────────────────
  /// 스캐폴드 배경. 빛바랜 속지 톤의 웜 베이지.
  static const bg = Color(0xFFEDE3D0);

  /// 바탕의 그늘진 면. 서랍 안쪽, 눌린 영역.
  static const bgDeep = Color(0xFFDFD2B8);

  // ── 잉크 ─────────────────────────────────────────
  /// 본문·제목. 도록 인쇄 잉크(순검정이 아닌 세피아 섞인 흑).
  static const ink = Color(0xFF251E15);

  /// 보조 텍스트. 바랜 잉크.
  static const inkSoft = Color(0xFF6E6152);

  /// 헤어라인. 구분선·비활성 보더.
  static const line = Color(0xFFD3C6AC);

  // ── 종이 ─────────────────────────────────────────
  /// 티켓·카드 용지. 바탕보다 살짝 밝고 노란 지질.
  static const stock = Color(0xFFF6F0E2);
  static const stockLight = Color(0xFFFCF8EE);

  /// 종이 두께·접힌 자국·절취선.
  static const pulp = Color(0xFFC7BBA2);

  /// 마닐라 크라프트. 서류철 기본색.
  static const kraft = Color(0xFFB08F5C);
  static const kraftDeep = Color(0xFF8E6F42);

  // ── 액센트 ───────────────────────────────────────
  /// 시그니처. 전시 도록의 옥스블러드.
  static const oxblood = Color(0xFF6B1F1A);
  static const oxbloodDim = Color(0xFF471310);

  /// 캡션 플레이트의 황동.
  static const foil = Color(0xFF8C7134);

  /// 다이모 라벨 테이프. 엠보싱 블랙.
  static const dymo = Color(0xFF1E1A15);

  /// 서류철 색. 종이를 물들인 듯 채도를 눌렀습니다.
  static const tabColors = <Color>[
    Color(0xFF6B1F1A), // 옥스블러드
    Color(0xFF44503F), // 올리브
    Color(0xFF2F3D4C), // 네이비
    Color(0xFFB08F5C), // 마닐라 크라프트
    Color(0xFF7C6047), // 다크 크라프트
  ];

  /// 홀로그램 오버레이 그라디언트.
  static const holo = <Color>[
    Color(0x66FF9BB0),
    Color(0x668FD8FF),
    Color(0x66C8FFB0),
    Color(0x66FFE59B),
  ];
}