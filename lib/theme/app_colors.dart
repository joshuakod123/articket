import 'package:flutter/material.dart';

/// Articket 팔레트 — "전시장 벽" 라이트 테마.
///
/// 미술관 내부의 실제 재료에서 뽑았습니다:
/// 미색 플라스터 벽, 살짝 눌린 티켓 용지, 도록의 옥스블러드 잉크,
/// 캡션 플레이트의 황동. 어두운 화면 대신 벽에 종이가 걸린 구도를 만듭니다.
class AppColors {
  AppColors._();

  // ── 전시장 벽 ─────────────────────────────────────
  /// 스캐폴드 배경. 미색 플라스터 벽.
  static const bg = Color(0xFFF1ECE1);

  /// 벽의 그늘진 면. 시트 하단, 눌린 영역.
  static const bgDeep = Color(0xFFE7DFCF);

  // ── 잉크 ─────────────────────────────────────────
  /// 본문·제목. 도록 인쇄 잉크(순검정 아님, 세피아 섞인 흑).
  static const ink = Color(0xFF221C14);

  /// 보조 텍스트. 바랜 잉크.
  static const inkSoft = Color(0xFF6F6557);

  /// 헤어라인. 구분선·비활성 보더.
  static const line = Color(0xFFD7CFBC);

  // ── 티켓 용지 ─────────────────────────────────────
  /// 티켓 스톡. 벽보다 살짝 밝고 노란 용지.
  static const stock = Color(0xFFF8F4E9);
  static const stockLight = Color(0xFFFDFBF4);

  /// 종이 두께·접힌 자국·절취선.
  static const pulp = Color(0xFFCCC4B0);

  // ── 액센트 ───────────────────────────────────────
  /// 시그니처. 전시 도록의 옥스블러드.
  static const oxblood = Color(0xFF6B1F1A);
  static const oxbloodDim = Color(0xFF471310);

  /// 캡션 플레이트의 황동. 라이트 배경 위에서 읽히도록 한 톤 눌렀습니다.
  static const foil = Color(0xFF8C7134);

  /// 인덱스 탭(서류철) 색. 아카이브 문서철 톤.
  static const tabColors = <Color>[
    Color(0xFF6B1F1A), // 옥스블러드
    Color(0xFF3F4A3C), // 올리브
    Color(0xFF2E3B4E), // 네이비
    Color(0xFF9C7C34), // 황동
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