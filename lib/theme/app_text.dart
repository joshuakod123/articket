import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 서체는 역할이 겹치지 않게 넷으로 못 박습니다. 섞어 쓰지 않습니다.
///
/// - [display] Noto Serif KR : **제목**. 한글 명조. 전시명·서류철 이름·화면 타이틀.
/// - [plate]   Bodoni Moda   : 영문 전용 표제. 로고·표지처럼 ASCII만 오는 자리.
/// - [data]    Courier Prime : **분류 번호와 메타데이터**. FILE_01, 날짜, 발권 번호.
///                             타자기로 찍은 서류의 인상. 한글은 넣지 않습니다.
/// - [hand]    나눔펜스크립트 : **사용자 메모**. 한 줄 평, 손으로 쓴 라벨.
/// - [ui]      IBM Plex Sans KR : 본문·버튼·설명. 읽히는 게 목적인 자리.
class AppText {
  AppText._();

  /// 제목용 명조. 한글·영문 모두 이 글꼴 하나로 붙습니다.
  static TextStyle display({
    double size = 28,
    FontWeight weight = FontWeight.w600,
    Color? color,
    double height = 1.2,
    double spacing = -0.3,
  }) =>
      GoogleFonts.notoSerifKr(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: spacing,
      );

  /// 영문 전용 표제. 한글을 넣으면 대체 글꼴로 떨어지니 ASCII 자리에만 씁니다.
  static TextStyle plate({
    double size = 30,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double height = 1.05,
    double spacing = -0.4,
  }) =>
      GoogleFonts.bodoniModa(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: spacing,
      );

  /// 타자기 고정폭. 분류 번호·날짜·일련번호 전용.
  static TextStyle data({
    double size = 11,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double spacing = 0.8,
    double height = 1.3,
  }) =>
      GoogleFonts.courierPrime(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: spacing,
        height: height,
      );

  /// 다이모 라벨 테이프에 찍힌 글자. 대문자·넓은 자간이 기본입니다.
  static TextStyle dymo({
    double size = 10,
    Color? color,
    double spacing = 2.6,
  }) =>
      GoogleFonts.courierPrime(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: spacing,
        height: 1.0,
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

  /// 손글씨. 스크랩북에 직접 적어 넣은 메모·한 줄 평.
  static TextStyle hand({
    double size = 20,
    Color? color,
    double height = 1.3,
    FontWeight weight = FontWeight.w400,
  }) =>
      GoogleFonts.nanumPenScript(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  /// 섹션 위에 얹는 작은 대문자 라벨. ("EYEBROW")
  static TextStyle eyebrow({Color? color}) => GoogleFonts.courierPrime(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: color,
    letterSpacing: 2.4,
  );
}