import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 서체는 역할이 겹치지 않게 못 박습니다. 섞어 쓰지 않습니다.
///
/// - [wordmark] Bodoni Moda   : **로고 전용**. `ARTICKET` 한 자리에만.
/// - [display]  Gowun Batang  : **제목**. 전시명·서류철 이름·화면 타이틀.
/// - [plate]    Bodoni Moda   : 영문 전용 표제. ASCII만 오는 자리.
/// - [data]     Courier Prime : 분류 번호·날짜·발권 번호. 한글은 넣지 않습니다.
/// - [hand]     나눔펜스크립트 : 사용자 메모. 한 줄 평, 손으로 쓴 라벨.
/// - [ui]       IBM Plex Sans KR : 본문·버튼·설명.
///
/// 제목 서체를 Noto Serif KR에서 **고운바탕**으로 옮겼습니다.
/// Noto는 화면용으로 잘 만든 대신 표정이 없어서, 종이 질감 위에 얹으면
/// 혼자만 디지털처럼 보였습니다. 고운바탕은 획 끝이 붓처럼 살아 있고
/// 세로획이 가늘어, 도록 표제나 전시 제목에 훨씬 잘 붙습니다.
class AppText {
  AppText._();

  /// 로고 전용. 자간을 크게 벌려 표지 각인처럼 보이게 합니다.
  static TextStyle wordmark({
    double size = 17,
    Color? color,
    double spacing = 6.5,
    FontWeight weight = FontWeight.w600,
  }) =>
      GoogleFonts.bodoniModa(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: spacing,
        height: 1.0,
      );

  /// 제목용 명조. 한글·영문 모두 이 글꼴 하나로 붙습니다.
  ///
  /// 고운바탕은 400/700 두 굵기만 있어서, 그 사이 값을 넣으면 가까운 쪽으로
  /// 떨어집니다. 실수로 어중간한 굵기를 쓰지 않도록 기본을 700으로 둡니다.
  static TextStyle display({
    double size = 28,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double height = 1.28,
    double spacing = -0.4,
  }) =>
      GoogleFonts.gowunBatang(
        fontSize: size,
        fontWeight: weight == FontWeight.w400 ? FontWeight.w400 : FontWeight.w700,
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
  static TextStyle eyebrow({Color? color, double size = 10}) =>
      GoogleFonts.courierPrime(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 2.4,
      );
}