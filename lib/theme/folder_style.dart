import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 서류철 탭에 이름을 어떤 "필기구"로 적었는지.
///
/// 색만 고를 수 있던 서류철에 **서체**를 붙입니다. 라벨 하나를 바꾸는 게 아니라
/// "이 서류철을 무엇으로 적었나"를 고르는 감각이라, 실물 파일링의 결에 맞습니다.
enum FolderFont {
  dymo('다이모 라벨', '눌러 찍은 라벨 테이프'),
  typewriter('타자기', '서류에 직접 친 활자'),
  serif('도록 명조', '전시 도록 표제'),
  hand('손글씨', '펜으로 갈겨 쓴 이름'),
  poster('포스터 고딕', '두껍게 인쇄한 표제'),
  round('둥근 라벨', '말랑한 스티커 글씨');

  const FolderFont(this.label, this.hint);

  /// 편집 화면에 보여줄 이름.
  final String label;

  /// 한 줄 설명.
  final String hint;

  /// 다이모만 검은 라벨 테이프 위에 올라갑니다. 나머지는 표지에 직접 찍힙니다.
  bool get onTape => this == FolderFont.dymo;

  /// 대문자로 강제할지. (한글이 섞이면 자동으로 무시됩니다)
  bool get upperCase => this == FolderFont.dymo || this == FolderFont.typewriter;

  /// 같은 시각 크기를 내기 위한 서체별 보정. 손글씨는 작아 보여서 키웁니다.
  double get sizeScale => switch (this) {
    FolderFont.hand => 1.75,
    FolderFont.round => 1.20,
    FolderFont.poster => 1.05,
    FolderFont.serif => 1.10,
    FolderFont.dymo => 1.0,
    FolderFont.typewriter => 1.05,
  };

  TextStyle style({double size = 12, Color? color}) {
    final s = size * sizeScale;
    return switch (this) {
      FolderFont.dymo => GoogleFonts.courierPrime(
        fontSize: s,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.6,
        height: 1.0,
        color: color,
      ),
      FolderFont.typewriter => GoogleFonts.courierPrime(
        fontSize: s,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        height: 1.05,
        color: color,
      ),
      FolderFont.serif => GoogleFonts.notoSerifKr(
        fontSize: s,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.1,
        color: color,
      ),
      FolderFont.hand => GoogleFonts.nanumPenScript(
        fontSize: s,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        height: 1.0,
        color: color,
      ),
      FolderFont.poster => GoogleFonts.blackHanSans(
        fontSize: s,
        letterSpacing: 0.3,
        height: 1.1,
        color: color,
      ),
      FolderFont.round => GoogleFonts.jua(
        fontSize: s,
        letterSpacing: 0.2,
        height: 1.1,
        color: color,
      ),
    };
  }

  /// 저장/복원용. enum 인덱스 대신 이름을 씁니다(항목 순서가 바뀌어도 안전).
  static FolderFont parse(String? name) => FolderFont.values.firstWhere(
        (f) => f.name == name,
    orElse: () => FolderFont.dymo,
  );
}

/// 표지를 무엇으로 쌌는지. 색과 별개로 **표면의 결**을 고릅니다.
enum FolderTexture {
  kraft('크라프트지', '거친 마닐라 서류철'),
  linen('리넨 클로스', '양장본 표지처럼 짜인 결'),
  leather('가죽', '손때 먹은 바인더'),
  marble('마블 페이퍼', '고서 면지의 물결무늬'),
  pressboard('프레스보드', '눌러 굳힌 판지');

  const FolderTexture(this.label, this.hint);

  final String label;
  final String hint;

  /// 표면이 빛을 얼마나 되받는지. 가죽·리넨은 살짝 윤이 납니다.
  double get sheen => switch (this) {
    FolderTexture.kraft => 0.05,
    FolderTexture.linen => 0.11,
    FolderTexture.leather => 0.16,
    FolderTexture.marble => 0.13,
    FolderTexture.pressboard => 0.06,
  };

  static FolderTexture parse(String? name) => FolderTexture.values.firstWhere(
        (t) => t.name == name,
    orElse: () => FolderTexture.kraft,
  );
}