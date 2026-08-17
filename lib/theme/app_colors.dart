import 'package:flutter/material.dart';

/// Articket 팔레트.
///
/// 참고 이미지의 전시 인쇄물 톤에서 뽑았습니다.
/// 흔한 "따뜻한 크림 + 테라코타" 조합을 피하고,
/// 실제 티켓 용지의 회녹빛 언더톤과 전시 도록의 옥스블러드로 잡았습니다.
class AppColors {
  AppColors._();

  /// 갤러리 벽 / 인쇄 잉크. 배경과 본문 텍스트.
  static const ink = Color(0xFF14110F);
  static const inkSoft = Color(0xFF3A3430);

  /// 티켓 용지. 순수 크림이 아니라 회녹빛이 살짝 도는 실제 지질.
  static const stock = Color(0xFFE8E2D4);
  static const stockLight = Color(0xFFF4F0E7);

  /// 접힌 자국 / 그림자 / 종이 두께.
  static const pulp = Color(0xFFC9C2B2);

  /// 시그니처 액센트. 전시 도록의 옥스블러드.
  static const oxblood = Color(0xFF6E1F1B);
  static const oxbloodDim = Color(0xFF4A1512);

  /// 박 인쇄. 반짝이는 금색이 아닌 눌린 황동.
  static const foil = Color(0xFFB08B3E);

  /// 인덱스 탭 색상. 서류철 색인지 톤.
  static const tabColors = <Color>[
    Color(0xFF6E1F1B), // 옥스블러드
    Color(0xFF3F4A3C), // 올리브
    Color(0xFF2E3B4E), // 네이비
    Color(0xFFB08B3E), // 황동
    Color(0xFF7A5C48), // 크라프트
  ];

  /// 홀로그램 오버레이 그라디언트.
  static const holo = <Color>[
    Color(0x66FF9BB0),
    Color(0x668FD8FF),
    Color(0x66C8FFB0),
    Color(0x66FFE59B),
  ];
}