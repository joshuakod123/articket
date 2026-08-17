import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 세 가지 역할로 서체를 나눕니다.
///
/// - [display] Bodoni Moda : 전시 제목. 미술관 포스터의 고대비 세리프.
/// - [data]    Space Mono  : 티켓 메타데이터. 발권기가 찍어낸 듯한 고정폭.
/// - [ui]      IBM Plex Sans KR : 한글 본문과 UI 라벨.
class AppText {
  AppText._();

  static TextStyle display({
    double size = 28,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double height = 1.1,
    double spacing = -0.4,
  }) =>
      GoogleFonts.bodoniModa(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: spacing,
      );

  static TextStyle data({
    double size = 11,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double spacing = 1.2,
    double height = 1.3,
  }) =>
      GoogleFonts.spaceMono(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: spacing,
        height: height,
      );

  static TextStyle ui({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.5,
    double spacing = 0,
  }) =>
      GoogleFonts.ibmPlexSansKr(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: spacing,
      );

  /// 섹션 위에 얹는 작은 대문자 라벨. ("EYEBROW")
  static TextStyle eyebrow({Color? color}) => GoogleFonts.spaceMono(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: color,
    letterSpacing: 2.4,
  );
}